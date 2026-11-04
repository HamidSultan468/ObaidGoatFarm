import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { Money } from '../../common/money/money.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { computeProfitability } from '../accounting/reports/tagged-profitability.util.js';
import { ReportsService } from '../accounting/reports/reports.service.js';
import { acreKanalMarla, convertArea } from '../land/area.util.js';
import {
  REPORT_TIME_ZONE,
  balanceSheetTotals,
  growthFromWeights,
  monthRange,
  monthlyTrend,
  percent,
} from './report-math.util.js';
import type { ReportDocument, ReportSection } from './report-table.js';

export interface Range {
  from: Date;
  to: Date;
}

const humanize = (v: string) => v.charAt(0) + v.slice(1).toLowerCase().replace(/_/g, ' ');
const day = (d: Date) => new Intl.DateTimeFormat('en-GB', { timeZone: REPORT_TIME_ZONE, day: '2-digit', month: 'short', year: 'numeric' }).format(d);
const periodLabel = (r: Range) => `${day(r.from)} – ${day(r.to)}`;
const sumMoney = (values: string[]) => Money.sum(values.map((v) => Money.from(v))).toFixed(4);

/**
 * The trend starts at the first month with activity (not at a far-back
 * "from" such as 2000-01-01, which would print hundreds of empty months);
 * with no activity at all it shows at most the last 12 months of the range.
 */
function trendStart(range: Range, postedDates: Date[]): Date {
  if (postedDates.length === 0) {
    const twelveBack = new Date(Date.UTC(range.to.getUTCFullYear(), range.to.getUTCMonth() - 11, 1));
    return twelveBack > range.from ? twelveBack : range.from;
  }
  const earliest = postedDates.reduce((min, d) => (d < min ? d : min));
  return earliest > range.from ? earliest : range.from;
}

/**
 * Cross-module reports (Phase 12). Every method returns `data` (structured,
 * for charts) and `document` (sections for the on-screen table and the
 * CSV/Excel/PDF exports). All amounts are exact decimal strings; every
 * query is scoped to one workspace.
 */
@Injectable()
export class AnalyticsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reports: ReportsService,
  ) {}

  private async doc(workspaceId: string, title: string, period: string, sections: ReportSection[]): Promise<ReportDocument> {
    const workspace = await this.prisma.workspace.findUniqueOrThrow({ where: { id: workspaceId }, select: { name: true } });
    return { title, workspaceName: workspace.name, period, generatedAt: new Date(), sections };
  }

  // --- Financial ---------------------------------------------------------------

  async financialSummary(workspaceId: string, range: Range) {
    const [pnl, cash, lines] = await Promise.all([
      this.reports.profitAndLoss(workspaceId, range.from, range.to),
      this.reports.cashFlow(workspaceId, range.from, range.to),
      this.prisma.journalLine.findMany({
        where: {
          account: { workspaceId, type: { in: ['INCOME', 'EXPENSE'] } },
          journalEntry: { status: 'POSTED', postedAt: { gte: range.from, lte: range.to } },
        },
        select: { amount: true, account: { select: { type: true } }, journalEntry: { select: { postedAt: true } } },
      }),
    ]);
    const trend = monthlyTrend(
      lines.map((l) => ({ amount: l.amount.toString(), accountType: l.account.type, postedAt: l.journalEntry.postedAt! })),
      // Entries are posted 'now', so months after today can only be empty.
      monthRange(trendStart(range, lines.map((l) => l.journalEntry.postedAt!)), range.to < new Date() ? range.to : new Date()),
    );
    const data = { range, profitAndLoss: pnl, cashFlow: cash, trend };
    const money = (key: string, label: string) => ({ key, label, type: 'money' as const });
    const document = await this.doc(workspaceId, 'Financial summary', periodLabel(range), [
      {
        title: 'Summary',
        columns: [{ key: 'metric', label: 'Metric', type: 'text' }, money('value', 'Amount')],
        rows: [
          { metric: 'Total income', value: pnl.totalIncome },
          { metric: 'Total expenses', value: pnl.totalExpense },
          { metric: 'Net profit', value: pnl.netProfit },
          { metric: 'Cash and bank: money in', value: cash.totalInflows },
          { metric: 'Cash and bank: money out', value: cash.totalOutflows },
          { metric: 'Cash and bank: net change', value: cash.netChange },
        ],
      },
      {
        title: 'Monthly trend',
        columns: [{ key: 'month', label: 'Month', type: 'text' }, money('income', 'Income'), money('expense', 'Expenses'), money('net', 'Net')],
        rows: trend.map((t) => ({ ...t })),
        totals: { month: 'Total', income: pnl.totalIncome, expense: pnl.totalExpense, net: pnl.netProfit },
      },
      {
        title: 'Income by category',
        columns: [{ key: 'code', label: 'Code', type: 'text' }, { key: 'name', label: 'Account', type: 'text' }, money('amount', 'Amount')],
        rows: pnl.income.map((r) => ({ ...r })),
        totals: { code: '', name: 'Total income', amount: pnl.totalIncome },
      },
      {
        title: 'Expenses by category',
        columns: [{ key: 'code', label: 'Code', type: 'text' }, { key: 'name', label: 'Account', type: 'text' }, money('amount', 'Amount')],
        rows: pnl.expenses.map((r) => ({ ...r })),
        totals: { code: '', name: 'Total expenses', amount: pnl.totalExpense },
      },
    ]);
    return { data, document };
  }

  /** Balances of every account as of `asOf`, and the accounting equation check. */
  async balanceSheet(workspaceId: string, asOf: Date) {
    const accounts = await this.prisma.account.findMany({
      where: { workspaceId },
      include: { journalLines: { where: { journalEntry: { status: 'POSTED', postedAt: { lte: asOf } } }, select: { amount: true } } },
      orderBy: { code: 'asc' },
    });
    const balances = accounts.map((a) => ({
      code: a.code,
      name: a.name,
      type: a.type,
      balance: Money.sum(a.journalLines.map((l) => Money.from(l.amount.toString()))).toFixed(4),
    }));
    const totals = balanceSheetTotals(balances);
    // Natural sign for display: credit-normal types shown positive.
    const natural = (type: string, balance: string) => (type === 'ASSET' ? balance : Money.from(balance).negate().toFixed(4));
    const section = (title: string, type: string, total: string): ReportSection => ({
      title,
      columns: [
        { key: 'code', label: 'Code', type: 'text' },
        { key: 'name', label: 'Account', type: 'text' },
        { key: 'balance', label: 'Balance', type: 'money' },
      ],
      rows: balances.filter((b) => b.type === type && !Money.from(b.balance).isZero()).map((b) => ({ code: b.code, name: b.name, balance: natural(type, b.balance) })),
      totals: { code: '', name: `Total ${title.toLowerCase()}`, balance: total },
    });
    const data = { asOf, ...totals, balanced: totals.difference === '0.0000' };
    const document = await this.doc(workspaceId, 'Balance sheet', `As of ${day(asOf)}`, [
      section('Assets', 'ASSET', totals.assets),
      section('Liabilities', 'LIABILITY', totals.liabilities),
      section('Equity', 'EQUITY', totals.equity),
      {
        title: 'Check',
        columns: [
          { key: 'metric', label: 'Line', type: 'text' },
          { key: 'value', label: 'Amount', type: 'money' },
        ],
        rows: [
          { metric: 'Total assets', value: totals.assets },
          { metric: 'Total liabilities', value: totals.liabilities },
          { metric: 'Total equity', value: totals.equity },
          { metric: 'Current earnings (income - expenses, not yet closed)', value: totals.currentEarnings },
          { metric: 'Difference (must be 0.00)', value: totals.difference },
        ],
      },
    ]);
    return { data, document };
  }

  async trialBalance(workspaceId: string) {
    const tb = await this.reports.trialBalance(workspaceId);
    const document = await this.doc(workspaceId, 'Trial balance', `As of ${day(new Date())}`, [
      {
        title: 'Trial balance',
        columns: [
          { key: 'code', label: 'Code', type: 'text' },
          { key: 'name', label: 'Account', type: 'text' },
          { key: 'type', label: 'Type', type: 'text' },
          { key: 'debit', label: 'Debit', type: 'money' },
          { key: 'credit', label: 'Credit', type: 'money' },
        ],
        rows: tb.rows.map((r) => ({ code: r.code, name: r.name, type: humanize(r.type), debit: r.debit, credit: r.credit })),
        totals: { code: '', name: tb.isBalanced ? 'Totals (balanced)' : 'Totals (NOT balanced)', type: '', debit: tb.totalDebit, credit: tb.totalCredit },
      },
    ]);
    return { data: tb, document };
  }

  // --- Farm ----------------------------------------------------------------------

  /**
   * Herd movement, kidding results and health activity for the period.
   * Per-animal profit is included only for callers allowed to see finances.
   */
  async farmPerformance(workspaceId: string, range: Range, includeFinancials: boolean) {
    const inRange = { gte: range.from, lte: range.to };
    const [activeNow, born, purchased, sold, deceased, kiddings, health] = await Promise.all([
      this.prisma.animal.count({ where: { workspaceId, status: 'ACTIVE' } }),
      this.prisma.animal.count({ where: { workspaceId, acquisition: 'BORN_ON_FARM', dateOfBirth: inRange } }),
      this.prisma.animal.count({ where: { workspaceId, acquisition: 'PURCHASED', acquisitionDate: inRange } }),
      this.prisma.animal.count({ where: { workspaceId, status: 'SOLD', exitDate: inRange } }),
      this.prisma.animal.count({ where: { workspaceId, status: 'DECEASED', exitDate: inRange } }),
      this.prisma.breedingRecord.findMany({ where: { workspaceId, status: 'KIDDED', kiddingDate: inRange }, select: { kidsBorn: true, kidsAlive: true } }),
      this.prisma.animalHealthRecord.groupBy({ by: ['type'], where: { workspaceId, recordDate: inRange }, _count: true }),
    ]);
    const kidsBorn = kiddings.reduce((n, k) => n + (k.kidsBorn ?? 0), 0);
    const kidsAlive = kiddings.reduce((n, k) => n + (k.kidsAlive ?? 0), 0);
    const herdBase = activeNow + sold + deceased;
    const kidding = {
      kiddings: kiddings.length,
      kidsBorn,
      kidsAlive,
      survivalPercent: percent(kidsAlive, kidsBorn),
      averageLitter: kiddings.length ? new Decimal(kidsBorn).dividedBy(kiddings.length).toDecimalPlaces(2, Decimal.ROUND_HALF_UP).toFixed(2) : null,
    };
    const herd = { activeNow, born, purchased, sold, deceased, mortalityPercent: percent(deceased, herdBase) };

    let profitability: Array<{ tagNumber: string; name: string | null; status: string; income: string; expense: string; net: string }> = [];
    if (includeFinancials) {
      const entries = await this.prisma.journalEntry.findMany({
        where: { workspaceId, status: 'POSTED', animalId: { not: null }, postedAt: inRange },
        select: { animalId: true, lines: { select: { amount: true, account: { select: { type: true } } } } },
      });
      const byAnimal = new Map<string, typeof entries>();
      for (const e of entries) byAnimal.set(e.animalId!, [...(byAnimal.get(e.animalId!) ?? []), e]);
      const animals = await this.prisma.animal.findMany({ where: { id: { in: [...byAnimal.keys()] } }, select: { id: true, tagNumber: true, name: true, status: true } });
      profitability = animals
        .map((a) => ({ tagNumber: a.tagNumber, name: a.name, status: humanize(a.status), ...computeProfitability(byAnimal.get(a.id)!) }))
        .sort((x, y) => Money.from(y.net).compareTo(Money.from(x.net)));
    }

    const sections: ReportSection[] = [
      {
        title: 'Herd movement',
        columns: [
          { key: 'metric', label: 'Metric', type: 'text' },
          { key: 'value', label: 'Value', type: 'number' },
        ],
        rows: [
          { metric: 'Animals on the farm now', value: activeNow },
          { metric: 'Born on the farm (period)', value: born },
          { metric: 'Purchased (period)', value: purchased },
          { metric: 'Sold (period)', value: sold },
          { metric: 'Died (period)', value: deceased },
          { metric: 'Mortality % (deaths / herd now + animals that left in the period)', value: herd.mortalityPercent ?? '—' },
        ],
      },
      {
        title: 'Kidding',
        columns: [
          { key: 'metric', label: 'Metric', type: 'text' },
          { key: 'value', label: 'Value', type: 'text' },
        ],
        rows: [
          { metric: 'Kiddings recorded', value: String(kidding.kiddings) },
          { metric: 'Kids born (incl. stillborn)', value: String(kidsBorn) },
          { metric: 'Kids alive at birth', value: String(kidsAlive) },
          { metric: 'Kid survival', value: kidding.survivalPercent ? `${kidding.survivalPercent}%` : '—' },
          { metric: 'Average litter size', value: kidding.averageLitter ?? '—' },
        ],
      },
      {
        title: 'Health events',
        columns: [
          { key: 'type', label: 'Type', type: 'text' },
          { key: 'count', label: 'Records', type: 'number' },
        ],
        rows: health.map((h) => ({ type: humanize(h.type), count: h._count })).sort((a, b) => b.count - a.count),
        totals: { type: 'Total', count: health.reduce((n, h) => n + h._count, 0) },
      },
    ];
    if (includeFinancials) {
      sections.push({
        title: 'Profit by animal',
        columns: [
          { key: 'tagNumber', label: 'Tag', type: 'text' },
          { key: 'name', label: 'Name', type: 'text' },
          { key: 'status', label: 'Status', type: 'text' },
          { key: 'income', label: 'Income', type: 'money' },
          { key: 'expense', label: 'Expenses', type: 'money' },
          { key: 'net', label: 'Net', type: 'money' },
        ],
        rows: profitability.map((p) => ({ ...p })),
        totals: profitability.length
          ? {
              tagNumber: 'Total',
              name: '',
              status: '',
              income: sumMoney(profitability.map((p) => p.income)),
              expense: sumMoney(profitability.map((p) => p.expense)),
              net: sumMoney(profitability.map((p) => p.net)),
            }
          : undefined,
      });
    }
    const document = await this.doc(workspaceId, 'Farm performance', periodLabel(range), sections);
    return { data: { range, herd, kidding, health: health.map((h) => ({ type: h.type, count: h._count })), profitability }, document };
  }

  /** Weight gain per animal between its first and last weighing in the period. */
  async animalGrowth(workspaceId: string, range: Range) {
    const weights = await this.prisma.animalWeightRecord.findMany({
      where: { workspaceId, recordDate: { gte: range.from, lte: range.to } },
      select: { animalId: true, recordDate: true, weightKg: true, animal: { select: { tagNumber: true, name: true, breed: true, sex: true, status: true } } },
      orderBy: { recordDate: 'asc' },
    });
    const byAnimal = new Map<string, typeof weights>();
    for (const w of weights) byAnimal.set(w.animalId, [...(byAnimal.get(w.animalId) ?? []), w]);
    const rows = [...byAnimal.values()]
      .map((list) => {
        const growth = growthFromWeights(list.map((w) => ({ recordDate: w.recordDate, weightKg: w.weightKg.toString() })));
        if (!growth) return null;
        const a = list[0].animal;
        return {
          tagNumber: a.tagNumber,
          name: a.name,
          breed: a.breed,
          sex: humanize(a.sex),
          firstDate: growth.firstDate.toISOString(),
          firstKg: growth.firstKg,
          lastDate: growth.lastDate.toISOString(),
          lastKg: growth.lastKg,
          gainKg: growth.gainKg,
          days: growth.days,
          adg: growth.adgGramsPerDay,
        };
      })
      .filter((r): r is NonNullable<typeof r> => r !== null)
      .sort((a, b) => new Decimal(b.adg ?? '-999999').comparedTo(a.adg ?? '-999999'));
    const document = await this.doc(workspaceId, 'Animal growth', periodLabel(range), [
      {
        title: 'Weight gain (first and last weighing in the period)',
        columns: [
          { key: 'tagNumber', label: 'Tag', type: 'text' },
          { key: 'name', label: 'Name', type: 'text' },
          { key: 'breed', label: 'Breed', type: 'text' },
          { key: 'sex', label: 'Sex', type: 'text' },
          { key: 'firstDate', label: 'First', type: 'date' },
          { key: 'firstKg', label: 'kg', type: 'decimal' },
          { key: 'lastDate', label: 'Last', type: 'date' },
          { key: 'lastKg', label: 'kg', type: 'decimal' },
          { key: 'gainKg', label: 'Gain kg', type: 'decimal' },
          { key: 'days', label: 'Days', type: 'number' },
          { key: 'adg', label: 'g/day', type: 'decimal' },
        ],
        rows: rows.map((r) => ({ ...r })),
      },
    ]);
    return { data: { range, animals: rows, weighedOnce: [...byAnimal.values()].filter((l) => l.length < 2).length }, document };
  }

  // --- Land -------------------------------------------------------------------

  async landReport(workspaceId: string, range: Range) {
    const [parcels, entries] = await Promise.all([
      this.prisma.landParcel.findMany({ where: { workspaceId }, orderBy: { name: 'asc' } }),
      this.prisma.journalEntry.findMany({
        where: { workspaceId, status: 'POSTED', landParcelId: { not: null }, postedAt: { gte: range.from, lte: range.to } },
        select: { landParcelId: true, lines: { select: { amount: true, account: { select: { type: true, code: true, name: true } } } } },
      }),
    ]);
    const perParcel = parcels.map((p) => {
      const mine = entries.filter((e) => e.landParcelId === p.id);
      const sqFt = p.areaSqFt.toString();
      return {
        parcelId: p.id,
        name: p.name,
        tenure: humanize(p.tenure),
        status: humanize(p.status),
        area: acreKanalMarla(sqFt),
        kanal: convertArea(sqFt).KANAL,
        ...computeProfitability(mine),
      };
    });
    const categories: Array<{ parcel: string; type: string; account: string; amount: string }> = [];
    for (const p of parcels) {
      const byAccount = new Map<string, { type: string; amount: Money }>();
      for (const e of entries.filter((x) => x.landParcelId === p.id)) {
        for (const l of e.lines) {
          if (l.account.type !== 'INCOME' && l.account.type !== 'EXPENSE') continue;
          const key = `${l.account.code} ${l.account.name}`;
          const current = byAccount.get(key) ?? { type: l.account.type, amount: Money.zero() };
          current.amount = current.amount.add(Money.from(l.amount.toString()));
          byAccount.set(key, current);
        }
      }
      for (const [account, v] of byAccount) {
        categories.push({ parcel: p.name, type: humanize(v.type), account, amount: (v.type === 'INCOME' ? v.amount.negate() : v.amount).toFixed(4) });
      }
    }
    const total = computeProfitability(entries);
    const document = await this.doc(workspaceId, 'Land income and expenses', periodLabel(range), [
      {
        title: 'By parcel',
        columns: [
          { key: 'name', label: 'Land', type: 'text' },
          { key: 'tenure', label: 'Tenure', type: 'text' },
          { key: 'kanal', label: 'Kanal', type: 'decimal' },
          { key: 'income', label: 'Income', type: 'money' },
          { key: 'expense', label: 'Expenses', type: 'money' },
          { key: 'net', label: 'Net', type: 'money' },
        ],
        rows: perParcel.map((p) => ({ name: p.name, tenure: p.tenure, kanal: p.kanal, income: p.income, expense: p.expense, net: p.net })),
        totals: { name: 'All land', tenure: '', kanal: '', income: total.income, expense: total.expense, net: total.net },
      },
      {
        title: 'By category',
        columns: [
          { key: 'parcel', label: 'Land', type: 'text' },
          { key: 'type', label: 'Type', type: 'text' },
          { key: 'account', label: 'Category', type: 'text' },
          { key: 'amount', label: 'Amount', type: 'money' },
        ],
        rows: categories.map((c) => ({ ...c })),
      },
    ]);
    return { data: { range, parcels: perParcel, total }, document };
  }

  // --- Audit & operations --------------------------------------------------------

  async auditLog(workspaceId: string, range: Range, action?: string) {
    const logs = await this.prisma.auditLog.findMany({
      where: { workspaceId, createdAt: { gte: range.from, lte: range.to }, ...(action ? { action: { contains: action, mode: 'insensitive' } } : {}) },
      include: { user: { select: { email: true } } },
      orderBy: { createdAt: 'desc' },
      take: 2000,
    });
    const rows = logs.map((l) => ({
      createdAt: l.createdAt.toISOString(),
      user: l.user?.email ?? '',
      action: l.action,
      entity: l.entityType.replace(/Controller$/, ''),
      entityId: l.entityId ?? '',
      ip: l.ipAddress ?? '',
    }));
    const document = await this.doc(workspaceId, 'Audit log', periodLabel(range), [
      {
        title: `Actions${action ? ` matching "${action}"` : ''}${logs.length === 2000 ? ' (latest 2000)' : ''}`,
        columns: [
          { key: 'createdAt', label: 'When (UTC)', type: 'datetime' },
          { key: 'user', label: 'User', type: 'text' },
          { key: 'action', label: 'Action', type: 'text' },
          { key: 'entity', label: 'Area', type: 'text' },
          { key: 'entityId', label: 'Record', type: 'text' },
          { key: 'ip', label: 'IP', type: 'text' },
        ],
        rows,
      },
    ]);
    return { data: { range, count: rows.length, entries: rows }, document };
  }

  async operations(workspaceId: string, range: Range) {
    const r = { gte: range.from, lte: range.to };
    const [posted, reversals, pending, rejected, drafts, backups, notifications, deliveries, docs, ai, whatsapp, byUser] = await Promise.all([
      this.prisma.journalEntry.count({ where: { workspaceId, status: 'POSTED', postedAt: r } }),
      this.prisma.journalEntry.count({ where: { workspaceId, reversalOfId: { not: null }, postedAt: r } }),
      this.prisma.journalEntry.count({ where: { workspaceId, status: 'PENDING_APPROVAL' } }),
      this.prisma.journalEntry.count({ where: { workspaceId, status: 'REJECTED', approvedAt: r } }),
      this.prisma.recordDraft.groupBy({ by: ['status'], where: { workspaceId, createdAt: r }, _count: true }),
      this.prisma.backup.groupBy({ by: ['status'], where: { workspaceId, startedAt: r }, _count: true }),
      this.prisma.notification.count({ where: { workspaceId, createdAt: r } }),
      this.prisma.notificationDelivery.groupBy({ by: ['status'], where: { notification: { workspaceId }, createdAt: r }, _count: true }),
      this.prisma.attachment.aggregate({ where: { workspaceId, createdAt: r }, _count: true, _sum: { sizeBytes: true } }),
      this.prisma.aiUsageLog.groupBy({ by: ['success'], where: { workspaceId, createdAt: r }, _count: true }),
      this.prisma.whatsAppMessageLog.groupBy({ by: ['status'], where: { workspaceId, direction: 'INBOUND', createdAt: r }, _count: true }),
      this.prisma.auditLog.groupBy({ by: ['userId'], where: { workspaceId, createdAt: r }, _count: true }),
    ]);
    const count = (rows: Array<{ _count: number; [k: string]: unknown }>, key: string, value: unknown) =>
      rows.find((row) => row[key] === value)?._count ?? 0;
    const metrics = [
      { area: 'Ledger', metric: 'Entries posted', value: posted },
      { area: 'Ledger', metric: 'Reversals', value: reversals },
      { area: 'Ledger', metric: 'Rejected entries', value: rejected },
      { area: 'Ledger', metric: 'Awaiting approval now', value: pending },
      { area: 'Drafts', metric: 'Created and still pending', value: count(drafts, 'status', 'PENDING') },
      { area: 'Drafts', metric: 'Approved', value: count(drafts, 'status', 'APPROVED') },
      { area: 'Drafts', metric: 'Rejected', value: count(drafts, 'status', 'REJECTED') },
      { area: 'Backups', metric: 'Completed', value: count(backups, 'status', 'COMPLETED') },
      { area: 'Backups', metric: 'Failed', value: count(backups, 'status', 'FAILED') },
      { area: 'Notifications', metric: 'Created', value: notifications },
      { area: 'Notifications', metric: 'Emails sent', value: count(deliveries, 'status', 'SENT') },
      { area: 'Notifications', metric: 'Emails failed', value: count(deliveries, 'status', 'FAILED') },
      { area: 'Documents', metric: 'Uploaded', value: docs._count },
      { area: 'AI', metric: 'Requests succeeded', value: count(ai, 'success', true) },
      { area: 'AI', metric: 'Requests failed', value: count(ai, 'success', false) },
      { area: 'WhatsApp', metric: 'Messages processed', value: count(whatsapp, 'status', 'PROCESSED') },
      { area: 'WhatsApp', metric: 'Messages ignored / failed', value: count(whatsapp, 'status', 'IGNORED') + count(whatsapp, 'status', 'FAILED') },
    ];
    const users = await this.prisma.user.findMany({ where: { id: { in: byUser.map((u) => u.userId).filter((id): id is string => !!id) } }, select: { id: true, email: true } });
    const activity = byUser
      .map((u) => ({ user: users.find((x) => x.id === u.userId)?.email ?? 'System', actions: u._count }))
      .sort((a, b) => b.actions - a.actions);
    const document = await this.doc(workspaceId, 'Operations', periodLabel(range), [
      {
        title: 'Activity',
        columns: [
          { key: 'area', label: 'Area', type: 'text' },
          { key: 'metric', label: 'Metric', type: 'text' },
          { key: 'value', label: 'Count', type: 'number' },
        ],
        rows: metrics.map((m) => ({ ...m })),
      },
      {
        title: 'Recorded actions by member',
        columns: [
          { key: 'user', label: 'Member', type: 'text' },
          { key: 'actions', label: 'Actions', type: 'number' },
        ],
        rows: activity.map((a) => ({ ...a })),
      },
    ]);
    return { data: { range, metrics, activity, documentBytes: docs._sum.sizeBytes ?? 0 }, document };
  }
}
