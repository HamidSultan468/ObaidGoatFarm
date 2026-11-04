import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { Money } from '../../../common/money/money.js';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Sum of every CASH/BANK-kind account's POSTED balance — the dashboard's "Bank Balance" KPI, computed exactly server-side rather than summed from floats client-side. */
  async liquidBalance(workspaceId: string): Promise<string> {
    const lines = await this.prisma.journalLine.findMany({
      where: { account: { workspaceId, kind: { in: ['CASH', 'BANK'] } }, journalEntry: { status: 'POSTED' } },
      select: { amount: true },
    });
    return Money.sum(lines.map((line) => Money.from(line.amount.toString()))).toFixed(4);
  }

  /** Every account with its POSTED balance — the sum across all accounts must be zero if the books are sound. */
  async trialBalance(workspaceId: string) {
    const accounts = await this.prisma.account.findMany({
      where: { workspaceId },
      include: { journalLines: { where: { journalEntry: { status: 'POSTED' } } } },
      orderBy: { code: 'asc' },
    });

    const rows = accounts.map((account) => {
      const balance = Money.sum(account.journalLines.map((line) => Money.from(line.amount.toString())));
      return {
        accountId: account.id,
        code: account.code,
        name: account.name,
        type: account.type,
        debit: balance.isNegative() ? '0.0000' : balance.toFixed(4),
        credit: balance.isNegative() ? balance.negate().toFixed(4) : '0.0000',
      };
    });

    const totalDebit = Money.sum(rows.map((row) => Money.from(row.debit)));
    const totalCredit = Money.sum(rows.map((row) => Money.from(row.credit)));

    return { rows, totalDebit: totalDebit.toFixed(4), totalCredit: totalCredit.toFixed(4), isBalanced: totalDebit.equals(totalCredit) };
  }

  /** Income minus Expense over [from, to] — the core "are we profitable" report. */
  async profitAndLoss(workspaceId: string, from: Date, to: Date) {
    const lines = await this.prisma.journalLine.findMany({
      where: {
        account: { workspaceId, type: { in: ['INCOME', 'EXPENSE'] } },
        journalEntry: { status: 'POSTED', postedAt: { gte: from, lte: to } },
      },
      include: { account: true },
    });

    const byAccount = new Map<string, { code: string; name: string; type: string; amount: Money }>();
    for (const line of lines) {
      const key = line.accountId;
      const existing = byAccount.get(key);
      const lineAmount = Money.from(line.amount.toString());
      if (existing) {
        existing.amount = existing.amount.add(lineAmount);
      } else {
        byAccount.set(key, { code: line.account.code, name: line.account.name, type: line.account.type, amount: lineAmount });
      }
    }

    // Income accounts carry a credit (negative) balance when money comes in; expense accounts carry a debit (positive) balance.
    const incomeRows = [...byAccount.values()]
      .filter((row) => row.type === 'INCOME')
      .map((row) => ({ code: row.code, name: row.name, amount: row.amount.negate().toFixed(4) }));
    const expenseRows = [...byAccount.values()]
      .filter((row) => row.type === 'EXPENSE')
      .map((row) => ({ code: row.code, name: row.name, amount: row.amount.toFixed(4) }));

    const totalIncome = Money.sum(incomeRows.map((row) => Money.from(row.amount)));
    const totalExpense = Money.sum(expenseRows.map((row) => Money.from(row.amount)));

    return {
      from: from.toISOString(),
      to: to.toISOString(),
      income: incomeRows,
      expenses: expenseRows,
      totalIncome: totalIncome.toFixed(4),
      totalExpense: totalExpense.toFixed(4),
      netProfit: totalIncome.subtract(totalExpense).toFixed(4),
    };
  }

  /**
   * Simplified cash flow: net change in CASH/BANK-kind accounts over
   * [from, to], broken down by the other side of each entry's accounts.
   * A full operating/investing/financing categorization is not implemented
   * yet — see ACCOUNTING.md for the scope note.
   */
  async cashFlow(workspaceId: string, from: Date, to: Date) {
    const cashLines = await this.prisma.journalLine.findMany({
      where: {
        account: { workspaceId, kind: { in: ['CASH', 'BANK'] } },
        journalEntry: { status: 'POSTED', postedAt: { gte: from, lte: to } },
      },
      include: { account: true },
    });

    const netChange = Money.sum(cashLines.map((line) => Money.from(line.amount.toString())));
    const inflows = Money.sum(
      cashLines.filter((line) => !Money.from(line.amount.toString()).isNegative()).map((line) => Money.from(line.amount.toString())),
    );
    const outflows = Money.sum(
      cashLines.filter((line) => Money.from(line.amount.toString()).isNegative()).map((line) => Money.from(line.amount.toString())),
    );

    return {
      from: from.toISOString(),
      to: to.toISOString(),
      totalInflows: inflows.toFixed(4),
      totalOutflows: outflows.negate().toFixed(4),
      netChange: netChange.toFixed(4),
    };
  }
}
