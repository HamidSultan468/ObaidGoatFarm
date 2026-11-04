import { BadRequestException } from '@nestjs/common';
import { Money } from '../../../common/money/money.js';

export interface BalanceLine {
  amount: string;
}

/**
 * The core invariant of double-entry bookkeeping: a journal entry's lines
 * (positive = debit, negative = credit) must sum to exactly zero. Pure and
 * DB-free so it's unit-testable without a database — see balance.util.spec.ts.
 */
export function assertBalanced(lines: BalanceLine[]): void {
  if (lines.length < 2) {
    throw new BadRequestException('A journal entry needs at least two lines');
  }

  const total = Money.sum(lines.map((line) => Money.from(line.amount)));
  if (!total.isZero()) {
    throw new BadRequestException(
      `Journal entry is not balanced: lines sum to ${total.toFixed(4)}, expected 0`,
    );
  }
}
