import { Decimal } from 'decimal.js';

export type AreaUnitValue = 'SQUARE_FOOT' | 'SQUARE_METER' | 'MARLA' | 'KANAL' | 'ACRE' | 'HECTARE';

/**
 * Square feet per unit. Marla uses the Punjab revenue (agricultural)
 * standard of 272.25 sq ft, so 1 kanal = 20 marla = 5,445 sq ft and
 * 1 acre = 8 kanal = 160 marla = 43,560 sq ft. Some urban housing schemes
 * use a 225 sq ft marla instead (DECISIONS.md D023).
 * Metric factors derive from 1 ft = 0.3048 m exactly.
 */
export const SQ_FT_PER_UNIT: Record<AreaUnitValue, Decimal> = {
  SQUARE_FOOT: new Decimal(1),
  SQUARE_METER: new Decimal(1).div(new Decimal('0.3048').pow(2)),
  MARLA: new Decimal('272.25'),
  KANAL: new Decimal('5445'),
  ACRE: new Decimal('43560'),
  HECTARE: new Decimal(10000).div(new Decimal('0.3048').pow(2)),
};

export const AREA_UNITS = Object.keys(SQ_FT_PER_UNIT) as AreaUnitValue[];

/** Canonical square feet for storage, rounded to 4 decimal places (half-up). */
export function toSquareFeet(value: string, unit: AreaUnitValue): string {
  return new Decimal(value).mul(SQ_FT_PER_UNIT[unit]).toDecimalPlaces(4, Decimal.ROUND_HALF_UP).toFixed(4);
}

/** The same area in every supported unit, 4 decimal places. */
export function convertArea(squareFeet: string): Record<AreaUnitValue, string> {
  const sqFt = new Decimal(squareFeet);
  return Object.fromEntries(
    AREA_UNITS.map((unit) => [unit, sqFt.div(SQ_FT_PER_UNIT[unit]).toDecimalPlaces(4, Decimal.ROUND_HALF_UP).toFixed(4)]),
  ) as Record<AreaUnitValue, string>;
}

/**
 * Traditional breakdown used on land records: `2 acre 3 kanal 5 marla`
 * plus any leftover square feet. Returns whole units only.
 */
export function acreKanalMarla(squareFeet: string): { acre: number; kanal: number; marla: number; squareFeet: string } {
  let rest = new Decimal(squareFeet);
  const take = (unit: AreaUnitValue) => {
    const whole = rest.div(SQ_FT_PER_UNIT[unit]).floor();
    rest = rest.sub(whole.mul(SQ_FT_PER_UNIT[unit]));
    return whole.toNumber();
  };
  const acre = take('ACRE');
  const kanal = take('KANAL');
  const marla = take('MARLA');
  return { acre, kanal, marla, squareFeet: rest.toDecimalPlaces(2).toFixed(2) };
}
