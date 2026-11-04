/**
 * A presentation-neutral report: titled sections of typed columns. Every
 * report endpoint builds one of these, and the CSV / Excel / PDF exporters
 * render it, so all three formats always show the same numbers.
 *
 * Money and decimal cells are exact decimal strings (never floats).
 */
export type CellType = 'text' | 'money' | 'number' | 'decimal' | 'percent' | 'date' | 'datetime';

export interface ReportColumn {
  key: string;
  label: string;
  type: CellType;
}

export type Cell = string | number | null;

export interface ReportSection {
  title: string;
  columns: ReportColumn[];
  rows: Array<Record<string, Cell>>;
  /** Optional totals row, keyed like `rows`. */
  totals?: Record<string, Cell>;
}

export interface ReportDocument {
  title: string;
  workspaceName: string;
  /** e.g. "01 Oct 2026 – 31 Oct 2026" */
  period: string;
  generatedAt: Date;
  sections: ReportSection[];
}

/** Text form of a cell for CSV/PDF: money with 2 decimals (exact), others as-is. */
export function formatCell(value: Cell, type: CellType): string {
  if (value === null || value === undefined || value === '') return '';
  if (type === 'money') return roundDecimalString(String(value), 2);
  if (type === 'percent') return `${value}%`;
  if (type === 'date') return String(value).slice(0, 10);
  if (type === 'datetime') return String(value).replace('T', ' ').slice(0, 19);
  return String(value);
}

/**
 * Rounds a decimal string half-up to `places` without floating point
 * ("1234.5650" -> "1234.57", "-0.005" -> "-0.01", "12" -> "12.00").
 */
export function roundDecimalString(value: string, places: number): string {
  const match = /^(-?)(\d+)(?:\.(\d+))?$/.exec(value.trim());
  if (!match) return value;
  const [, sign, intPart, fracPart = ''] = match;
  const scaled = BigInt(intPart + fracPart.padEnd(places + 1, '0').slice(0, places + 1));
  const rounded = (scaled + 5n) / 10n; // half-up on the magnitude
  const digits = rounded.toString().padStart(places + 1, '0');
  const whole = digits.slice(0, digits.length - places);
  const frac = places > 0 ? `.${digits.slice(digits.length - places)}` : '';
  const isZero = /^0+$/.test(whole + digits.slice(digits.length - places));
  return `${sign && !isZero ? '-' : ''}${whole}${frac}`;
}
