import { describe, expect, it } from 'vitest';
import { Money } from './money.js';

describe('Money', () => {
  it('adds without floating-point error', () => {
    const a = Money.from('0.1');
    const b = Money.from('0.2');
    expect(a.add(b).toFixed(2)).toBe('0.30');
    // sanity check that native JS float arithmetic would have failed this
    expect(0.1 + 0.2).not.toBe(0.3);
  });

  it('subtracts correctly', () => {
    const result = Money.from('100.00').subtract(Money.from('45.25'));
    expect(result.toFixed(2)).toBe('54.75');
  });

  it('negates correctly', () => {
    expect(Money.from('10.00').negate().toFixed(2)).toBe('-10.00');
  });

  it('detects zero', () => {
    expect(Money.zero().isZero()).toBe(true);
    expect(Money.from('0.00').isZero()).toBe(true);
    expect(Money.from('0.01').isZero()).toBe(false);
  });

  it('detects negative amounts', () => {
    expect(Money.from('-5').isNegative()).toBe(true);
    expect(Money.from('5').isNegative()).toBe(false);
  });

  it('compares amounts', () => {
    expect(Money.from('5').compareTo(Money.from('3'))).toBeGreaterThan(0);
    expect(Money.from('3').compareTo(Money.from('5'))).toBeLessThan(0);
    expect(Money.from('5').compareTo(Money.from('5'))).toBe(0);
  });

  it('checks equality', () => {
    expect(Money.from('5.00').equals(Money.from('5'))).toBe(true);
    expect(Money.from('5.00').equals(Money.from('5.01'))).toBe(false);
  });

  it('sums a list of amounts to zero when they net out (double-entry balance check)', () => {
    const lines = [Money.from('100.00'), Money.from('-60.00'), Money.from('-40.00')];
    expect(Money.sum(lines).isZero()).toBe(true);
  });

  it('sums a list and detects an unbalanced set of journal lines', () => {
    const lines = [Money.from('100.00'), Money.from('-60.00'), Money.from('-39.99')];
    expect(Money.sum(lines).isZero()).toBe(false);
  });
});
