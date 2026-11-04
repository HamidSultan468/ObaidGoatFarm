import { BadRequestException } from '@nestjs/common';
import { describe, expect, it } from 'vitest';
import { assertBalanced } from './balance.util.js';

describe('assertBalanced', () => {
  it('accepts a balanced two-line entry', () => {
    expect(() => assertBalanced([{ amount: '100.00' }, { amount: '-100.00' }])).not.toThrow();
  });

  it('accepts a balanced multi-line entry (one debit, several credits)', () => {
    expect(() =>
      assertBalanced([{ amount: '100.00' }, { amount: '-60.00' }, { amount: '-40.00' }]),
    ).not.toThrow();
  });

  it('rejects an unbalanced entry', () => {
    expect(() => assertBalanced([{ amount: '100.00' }, { amount: '-99.99' }])).toThrow(
      BadRequestException,
    );
  });

  it('rejects a single-line entry', () => {
    expect(() => assertBalanced([{ amount: '100.00' }])).toThrow(BadRequestException);
  });

  it('rejects an empty entry', () => {
    expect(() => assertBalanced([])).toThrow(BadRequestException);
  });

  it('is exact for amounts that would fail under floating point', () => {
    // 0.1 + 0.2 - 0.3 !== 0 in IEEE 754 float arithmetic.
    expect(() => assertBalanced([{ amount: '0.10' }, { amount: '0.20' }, { amount: '-0.30' }])).not.toThrow();
  });
});
