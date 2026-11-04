import { describe, expect, it } from 'vitest';
import { acreKanalMarla, convertArea, toSquareFeet } from './area.util.js';

describe('toSquareFeet', () => {
  it('uses the revenue marla (272.25 sq ft) and its multiples', () => {
    expect(toSquareFeet('1', 'MARLA')).toBe('272.2500');
    expect(toSquareFeet('1', 'KANAL')).toBe('5445.0000');
    expect(toSquareFeet('1', 'ACRE')).toBe('43560.0000');
    expect(toSquareFeet('20', 'MARLA')).toBe(toSquareFeet('1', 'KANAL'));
    expect(toSquareFeet('8', 'KANAL')).toBe(toSquareFeet('1', 'ACRE'));
  });

  it('converts metric units from the exact foot definition', () => {
    expect(toSquareFeet('1', 'SQUARE_METER')).toBe('10.7639');
    expect(toSquareFeet('1', 'HECTARE')).toBe('107639.1042');
  });

  it('keeps fractional input exact (no float drift)', () => {
    expect(toSquareFeet('0.1', 'KANAL')).toBe('544.5000');
    expect(toSquareFeet('2.5', 'ACRE')).toBe('108900.0000');
  });
});

describe('convertArea', () => {
  it('round-trips one acre into every unit', () => {
    const result = convertArea('43560');
    expect(result.ACRE).toBe('1.0000');
    expect(result.KANAL).toBe('8.0000');
    expect(result.MARLA).toBe('160.0000');
    expect(result.SQUARE_FOOT).toBe('43560.0000');
    expect(result.HECTARE).toBe('0.4047');
  });
});

describe('acreKanalMarla', () => {
  it('breaks an area into whole acre / kanal / marla plus leftover sq ft', () => {
    // 2 acre + 3 kanal + 5 marla + 100 sq ft
    const sqFt = String(2 * 43560 + 3 * 5445 + 5 * 272.25 + 100);
    expect(acreKanalMarla(sqFt)).toEqual({ acre: 2, kanal: 3, marla: 5, squareFeet: '100.00' });
  });

  it('handles areas smaller than a marla', () => {
    expect(acreKanalMarla('150')).toEqual({ acre: 0, kanal: 0, marla: 0, squareFeet: '150.00' });
  });
});
