import { Decimal } from 'decimal.js';

/** Reports bucket by calendar month in the business's time zone. */
export const REPORT_TIME_ZONE = 'Asia/Karachi';

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

/** Minutes the zone is ahead of UTC at `instant` (Asia/Karachi: +300). */
export function zoneOffsetMinutes(instant: Date, timeZone = REPORT_TIME_ZONE): number {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', { timeZone, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
      .formatToParts(instant)
      .map((p) => [p.type, p.value]),
  );
  const asUtc = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second);
  return Math.round((asUtc - Math.floor(instant.getTime() / 1000) * 1000) / 60_000);
}

/** The instant a calendar day ("2026-11-04") starts in the business time zone. */
export function zonedDayStart(day: string, timeZone = REPORT_TIME_ZONE): Date {
  const utcMidnight = new Date(`${day}T00:00:00.000Z`);
  return new Date(utcMidnight.getTime() - zoneOffsetMinutes(utcMidnight, timeZone) * 60_000);
}

/**
 * Inclusive date range from query strings, in the business's calendar
 * (Asia/Karachi): a date-only `from` starts at 00:00 local and a date-only
 * `to` ends at 23:59:59.999 local, so "to=2026-11-04" includes everything
 * posted on Nov 4 in Pakistan. Defaults: from = 1st of the current local
 * month, to = now. Returns null for unparseable input or from > to.
 */
export function parseInclusiveRange(from?: string, to?: string, now = new Date()): { from: Date; to: Date } | null {
  const nextDay = (day: string) => new Date(new Date(`${day}T00:00:00.000Z`).getTime() + 86_400_000).toISOString().slice(0, 10);
  const toDate = !to ? now : DATE_ONLY.test(to) ? new Date(zonedDayStart(nextDay(to)).getTime() - 1) : new Date(to);
  const fromDate = !from
    ? zonedDayStart(`${monthKey(now)}-01`)
    : DATE_ONLY.test(from)
      ? zonedDayStart(from)
      : new Date(from);
  if (Number.isNaN(fromDate.getTime()) || Number.isNaN(toDate.getTime()) || fromDate > toDate) return null;
  return { from: fromDate, to: toDate };
}

/** "2026-11" for an instant, in the report time zone. */
export function monthKey(date: Date, timeZone = REPORT_TIME_ZONE): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit' }).formatToParts(date);
  return `${parts.find((p) => p.type === 'year')!.value}-${parts.find((p) => p.type === 'month')!.value}`;
}

/** Every month key from `from` to `to` inclusive, so empty months still appear in trends. */
export function monthRange(from: Date, to: Date, timeZone = REPORT_TIME_ZONE): string[] {
  const start = monthKey(from, timeZone);
  const end = monthKey(to, timeZone);
  const keys: string[] = [];
  let [year, month] = start.split('-').map(Number);
  for (let guard = 0; guard < 600; guard++) {
    const key = `${year}-${String(month).padStart(2, '0')}`;
    keys.push(key);
    if (key === end) break;
    month += 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
  }
  return keys;
}

export interface MonthTotals {
  month: string;
  income: string;
  expense: string;
  net: string;
}

/**
 * Monthly income/expense from ledger lines (debit positive, credit
 * negative): INCOME lines count as -amount, EXPENSE lines as +amount.
 * Exact decimals throughout.
 */
export function monthlyTrend(
  lines: Array<{ amount: string; accountType: string; postedAt: Date }>,
  months: string[],
  timeZone = REPORT_TIME_ZONE,
): MonthTotals[] {
  const totals = new Map(months.map((m) => [m, { income: new Decimal(0), expense: new Decimal(0) }]));
  for (const line of lines) {
    const bucket = totals.get(monthKey(line.postedAt, timeZone));
    if (!bucket) continue;
    if (line.accountType === 'INCOME') bucket.income = bucket.income.minus(line.amount);
    else if (line.accountType === 'EXPENSE') bucket.expense = bucket.expense.plus(line.amount);
  }
  return months.map((month) => {
    const { income, expense } = totals.get(month)!;
    return { month, income: income.toFixed(4), expense: expense.toFixed(4), net: income.minus(expense).toFixed(4) };
  });
}

export interface GrowthRow {
  firstDate: Date;
  lastDate: Date;
  firstKg: string;
  lastKg: string;
  gainKg: string;
  days: number;
  /** Average daily gain in grams/day, 1 decimal; null when < 1 day apart. */
  adgGramsPerDay: string | null;
}

/** Growth between the first and last weight (records sorted by date). Null if fewer than two weights. */
export function growthFromWeights(weights: Array<{ recordDate: Date; weightKg: string }>): GrowthRow | null {
  if (weights.length < 2) return null;
  const sorted = [...weights].sort((a, b) => a.recordDate.getTime() - b.recordDate.getTime());
  const first = sorted[0];
  const last = sorted[sorted.length - 1];
  const gain = new Decimal(last.weightKg).minus(first.weightKg);
  const days = Math.round((last.recordDate.getTime() - first.recordDate.getTime()) / 86_400_000);
  return {
    firstDate: first.recordDate,
    lastDate: last.recordDate,
    firstKg: new Decimal(first.weightKg).toFixed(3),
    lastKg: new Decimal(last.weightKg).toFixed(3),
    gainKg: gain.toFixed(3),
    days,
    adgGramsPerDay: days >= 1 ? gain.times(1000).dividedBy(days).toDecimalPlaces(1, Decimal.ROUND_HALF_UP).toFixed(1) : null,
  };
}

/** `part / whole` as a percentage string with 1 decimal; null when whole is 0. */
export function percent(part: number, whole: number): string | null {
  if (whole === 0) return null;
  return new Decimal(part).times(100).dividedBy(whole).toDecimalPlaces(1, Decimal.ROUND_HALF_UP).toFixed(1);
}

export interface BalanceSheetTotals {
  assets: string;
  liabilities: string;
  equity: string;
  /** Income minus expenses to date, not yet closed into equity. */
  currentEarnings: string;
  /** Assets - (liabilities + equity + current earnings); "0.0000" when the books balance. */
  difference: string;
}

/**
 * Natural balances by account type (assets debit-positive; liabilities,
 * equity and income credit-positive). The accounting equation holds when
 * `difference` is exactly zero.
 */
export function balanceSheetTotals(balances: Array<{ type: string; balance: string }>): BalanceSheetTotals {
  let assets = new Decimal(0);
  let liabilities = new Decimal(0);
  let equity = new Decimal(0);
  let earnings = new Decimal(0);
  for (const { type, balance } of balances) {
    if (type === 'ASSET') assets = assets.plus(balance);
    else if (type === 'LIABILITY') liabilities = liabilities.minus(balance);
    else if (type === 'EQUITY') equity = equity.minus(balance);
    else if (type === 'INCOME') earnings = earnings.minus(balance);
    else if (type === 'EXPENSE') earnings = earnings.minus(balance);
  }
  return {
    assets: assets.toFixed(4),
    liabilities: liabilities.toFixed(4),
    equity: equity.toFixed(4),
    currentEarnings: earnings.toFixed(4),
    difference: assets.minus(liabilities).minus(equity).minus(earnings).toFixed(4),
  };
}
