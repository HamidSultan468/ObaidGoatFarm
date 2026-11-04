import { Money } from '../../../common/money/money.js';

export interface TaggedLine {
  amount: { toString(): string };
  account: { type: string };
}

export interface TaggedEntry {
  lines: TaggedLine[];
}

export interface Profitability {
  income: string;
  expense: string;
  net: string;
}

/**
 * Income/expense/net for a set of POSTED journal entries that share a tag
 * (an animal or a land parcel). Only INCOME and EXPENSE lines count: the
 * cash/bank side of each entry is just where the money moved.
 *
 * Ledger sign convention: debit positive, credit negative. INCOME lines are
 * credits, so income = -(sum of INCOME lines); EXPENSE lines are debits, so
 * expense = sum of EXPENSE lines. Reversals carry flipped signs and
 * therefore cancel the entry they reverse automatically.
 */
export function computeProfitability(entries: TaggedEntry[]): Profitability {
  let income = Money.zero();
  let expense = Money.zero();

  for (const entry of entries) {
    for (const line of entry.lines) {
      const amount = Money.from(line.amount.toString());
      if (line.account.type === 'INCOME') {
        income = income.subtract(amount);
      } else if (line.account.type === 'EXPENSE') {
        expense = expense.add(amount);
      }
    }
  }

  return {
    income: income.toFixed(4),
    expense: expense.toFixed(4),
    net: income.subtract(expense).toFixed(4),
  };
}
