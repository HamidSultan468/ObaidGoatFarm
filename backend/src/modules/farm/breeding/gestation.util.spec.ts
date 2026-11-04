import { describe, expect, it } from 'vitest';
import { canRecordKidding, canTransition, expectedKiddingDate } from './gestation.util.js';

describe('expectedKiddingDate', () => {
  it('adds 150 days by default', () => {
    expect(expectedKiddingDate(new Date('2026-01-01T00:00:00Z')).toISOString()).toBe('2026-05-31T00:00:00.000Z');
  });

  it('accepts a custom gestation length', () => {
    expect(expectedKiddingDate(new Date('2026-03-01T00:00:00Z'), 145).toISOString()).toBe('2026-07-24T00:00:00.000Z');
  });
});

describe('breeding status transitions', () => {
  it('allows confirming or ruling out pregnancy from MATED', () => {
    expect(canTransition('MATED', 'PREGNANT')).toBe(true);
    expect(canTransition('MATED', 'NOT_PREGNANT')).toBe(true);
  });

  it('never allows KIDDED as a manual transition', () => {
    expect(canTransition('PREGNANT', 'KIDDED')).toBe(false);
    expect(canTransition('MATED', 'KIDDED')).toBe(false);
  });

  it('treats final states as final', () => {
    expect(canTransition('KIDDED', 'PREGNANT')).toBe(false);
    expect(canTransition('ABORTED', 'MATED')).toBe(false);
  });

  it('allows kidding only from MATED or PREGNANT', () => {
    expect(canRecordKidding('MATED')).toBe(true);
    expect(canRecordKidding('PREGNANT')).toBe(true);
    expect(canRecordKidding('KIDDED')).toBe(false);
    expect(canRecordKidding('NOT_PREGNANT')).toBe(false);
  });
});
