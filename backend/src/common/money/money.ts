import { Decimal } from 'decimal.js';

/**
 * Centralized money value object. All monetary arithmetic in the platform
 * must go through this class — never raw `number`/`Float` — per
 * CLAUDE.md §3 ("Never use floating-point arithmetic for financial
 * calculations") and DECISIONS.md D004.
 *
 * Internally backed by decimal.js (arbitrary-precision decimal), persisted
 * via Prisma's `Decimal` (`numeric(18,4)`).
 */
export class Money {
  private readonly value: Decimal;

  private constructor(value: Decimal) {
    this.value = value;
  }

  static zero(): Money {
    return new Money(new Decimal(0));
  }

  /** Accepts a string or Decimal — never a `number`, to avoid silent float precision loss at the call site. */
  static from(value: string | Decimal): Money {
    return new Money(new Decimal(value));
  }

  add(other: Money): Money {
    return new Money(this.value.plus(other.value));
  }

  subtract(other: Money): Money {
    return new Money(this.value.minus(other.value));
  }

  negate(): Money {
    return new Money(this.value.negated());
  }

  isZero(): boolean {
    return this.value.isZero();
  }

  isNegative(): boolean {
    return this.value.isNegative();
  }

  equals(other: Money): boolean {
    return this.value.equals(other.value);
  }

  compareTo(other: Money): number {
    return this.value.comparedTo(other.value);
  }

  /** Rounded to the given currency's minor-unit precision (default 2 decimal places). */
  toFixed(decimalPlaces = 2): string {
    return this.value.toFixed(decimalPlaces);
  }

  toDecimal(): Decimal {
    return this.value;
  }

  static sum(amounts: Money[]): Money {
    return amounts.reduce((total, amount) => total.add(amount), Money.zero());
  }
}
