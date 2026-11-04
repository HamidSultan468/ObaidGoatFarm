import { describe, expect, it } from 'vitest';
import { IDEMPOTENCY_KEY_PATTERN, canonicalJson, requestHash, versionMatches } from './idempotency.util.js';

describe('idempotency', () => {
  it('canonical JSON ignores key order and undefined', () => {
    expect(canonicalJson({ b: 1, a: { d: [1, { y: 2, x: 1 }], c: undefined } })).toBe('{"a":{"d":[1,{"x":1,"y":2}]},"b":1}');
  });

  it('same request -> same hash; different body or path -> different hash', () => {
    const a = requestHash('post', '/w/1/transactions/income', { amount: '10.00', toAccountId: 'x' });
    expect(requestHash('POST', '/w/1/transactions/income', { toAccountId: 'x', amount: '10.00' })).toBe(a);
    expect(requestHash('POST', '/w/1/transactions/income', { toAccountId: 'x', amount: '10.01' })).not.toBe(a);
    expect(requestHash('POST', '/w/2/transactions/income', { toAccountId: 'x', amount: '10.00' })).not.toBe(a);
  });

  it('accepts UUIDs and rejects junk keys', () => {
    expect(IDEMPOTENCY_KEY_PATTERN.test('3f2b9c1e-8f2a-4d3b-9a77-0c1d2e3f4a5b')).toBe(true);
    expect(IDEMPOTENCY_KEY_PATTERN.test('short')).toBe(false);
    expect(IDEMPOTENCY_KEY_PATTERN.test('has spaces in it')).toBe(false);
  });
});

describe('versionMatches (If-Match)', () => {
  const current = new Date('2026-11-04T10:20:30.123Z');

  it('no header = no precondition', () => {
    expect(versionMatches(undefined, current)).toBe(true);
  });

  it('matches the exact version, with or without quotes / W/', () => {
    expect(versionMatches('2026-11-04T10:20:30.123Z', current)).toBe(true);
    expect(versionMatches('"2026-11-04T10:20:30.123Z"', current)).toBe(true);
    expect(versionMatches('W/"2026-11-04T10:20:30.123Z"', current)).toBe(true);
  });

  it('rejects an older version or garbage', () => {
    expect(versionMatches('2026-11-04T10:20:30.000Z', current)).toBe(false);
    expect(versionMatches('yesterday', current)).toBe(false);
  });
});
