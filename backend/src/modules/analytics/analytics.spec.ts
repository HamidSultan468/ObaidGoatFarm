import { inflateRawSync } from 'node:zlib';
import { describe, expect, it } from 'vitest';
import { toCsv } from './exporters/csv.exporter.js';
import { toPdf } from './exporters/pdf.exporter.js';
import { columnName, toXlsx } from './exporters/xlsx.exporter.js';
import {
  balanceSheetTotals,
  growthFromWeights,
  monthKey,
  monthRange,
  monthlyTrend,
  parseInclusiveRange,
  percent,
} from './report-math.util.js';
import { formatCell, roundDecimalString, type ReportDocument } from './report-table.js';

describe('roundDecimalString (no floats)', () => {
  it('rounds half-up exactly', () => {
    expect(roundDecimalString('1234.5650', 2)).toBe('1234.57');
    expect(roundDecimalString('1234.5649', 2)).toBe('1234.56');
    expect(roundDecimalString('12', 2)).toBe('12.00');
    expect(roundDecimalString('-0.005', 2)).toBe('-0.01');
    expect(roundDecimalString('-0.004', 2)).toBe('0.00');
    expect(roundDecimalString('99999999999999.9950', 2)).toBe('100000000000000.00');
  });
});

describe('parseInclusiveRange', () => {
  it('uses whole Pakistan calendar days (UTC+5): from 00:00 PKT to 23:59:59.999 PKT', () => {
    const r = parseInclusiveRange('2026-11-01', '2026-11-04')!;
    expect(r.from.toISOString()).toBe('2026-10-31T19:00:00.000Z');
    expect(r.to.toISOString()).toBe('2026-11-04T18:59:59.999Z');
  });

  it('an entry at 21:00 UTC on Nov 4 is Nov 5 in Pakistan, so it falls in the Nov 5 range', () => {
    const entry = new Date('2026-11-04T21:00:00Z');
    const nov4 = parseInclusiveRange('2026-11-04', '2026-11-04')!;
    const nov5 = parseInclusiveRange('2026-11-05', '2026-11-05')!;
    expect(entry >= nov4.from && entry <= nov4.to).toBe(false);
    expect(entry >= nov5.from && entry <= nov5.to).toBe(true);
  });

  it('rejects reversed or invalid ranges', () => {
    expect(parseInclusiveRange('2026-12-01', '2026-11-01')).toBeNull();
    expect(parseInclusiveRange('nonsense', undefined)).toBeNull();
  });
});

describe('months', () => {
  it('buckets by Karachi local month (UTC 20:00 on Oct 31 is already November)', () => {
    expect(monthKey(new Date('2026-10-31T20:00:00Z'))).toBe('2026-11');
  });

  it('lists every month in the range, across a year boundary', () => {
    expect(monthRange(new Date('2026-11-10T00:00:00Z'), new Date('2027-02-01T00:00:00Z'))).toEqual(['2026-11', '2026-12', '2027-01', '2027-02']);
  });

  it('sums income and expense per month exactly, keeping empty months', () => {
    const trend = monthlyTrend(
      [
        { amount: '-0.10', accountType: 'INCOME', postedAt: new Date('2026-11-02T00:00:00Z') },
        { amount: '-0.20', accountType: 'INCOME', postedAt: new Date('2026-11-03T00:00:00Z') },
        { amount: '0.30', accountType: 'EXPENSE', postedAt: new Date('2026-11-04T00:00:00Z') },
        { amount: '0.30', accountType: 'ASSET', postedAt: new Date('2026-11-04T00:00:00Z') },
      ],
      ['2026-10', '2026-11'],
    );
    expect(trend).toEqual([
      { month: '2026-10', income: '0.0000', expense: '0.0000', net: '0.0000' },
      { month: '2026-11', income: '0.3000', expense: '0.3000', net: '0.0000' },
    ]);
  });
});

describe('growthFromWeights', () => {
  it('computes gain and average daily gain in g/day', () => {
    const g = growthFromWeights([
      { recordDate: new Date('2026-10-01T00:00:00Z'), weightKg: '30.000' },
      { recordDate: new Date('2026-11-01T00:00:00Z'), weightKg: '34.650' },
    ])!;
    expect(g).toMatchObject({ firstKg: '30.000', lastKg: '34.650', gainKg: '4.650', days: 31, adgGramsPerDay: '150.0' });
  });

  it('handles weight loss and needs two weights', () => {
    expect(growthFromWeights([{ recordDate: new Date(), weightKg: '30' }])).toBeNull();
    const loss = growthFromWeights([
      { recordDate: new Date('2026-11-01T00:00:00Z'), weightKg: '31' },
      { recordDate: new Date('2026-11-11T00:00:00Z'), weightKg: '30' },
    ])!;
    expect(loss.gainKg).toBe('-1.000');
    expect(loss.adgGramsPerDay).toBe('-100.0');
  });
});

describe('percent / balance sheet', () => {
  it('percent is exact and null for an empty base', () => {
    expect(percent(2, 3)).toBe('66.7');
    expect(percent(1, 0)).toBeNull();
  });

  it('balances assets = liabilities + equity + current earnings', () => {
    const totals = balanceSheetTotals([
      { type: 'ASSET', balance: '150000.0000' }, // cash
      { type: 'LIABILITY', balance: '-20000.0000' }, // loan
      { type: 'EQUITY', balance: '-100000.0000' }, // owner's capital
      { type: 'INCOME', balance: '-45000.0000' },
      { type: 'EXPENSE', balance: '15000.0000' },
    ]);
    expect(totals).toEqual({ assets: '150000.0000', liabilities: '20000.0000', equity: '100000.0000', currentEarnings: '30000.0000', difference: '0.0000' });
  });
});

const doc: ReportDocument = {
  title: 'Profit & Loss',
  workspaceName: 'Obaid Goat Farm',
  period: '01 Nov 2026 – 30 Nov 2026',
  generatedAt: new Date('2026-11-04T10:00:00Z'),
  sections: [
    {
      title: 'Income',
      columns: [
        { key: 'name', label: 'Account', type: 'text' },
        { key: 'amount', label: 'Amount', type: 'money' },
      ],
      rows: [
        { name: 'Sales, "goats"', amount: '45000.5050' },
        { name: '=HYPERLINK("http://evil")', amount: '1.0000' },
        { name: 'دودھ کی فروخت', amount: '300.0000' },
      ],
      totals: { name: 'Total', amount: '45301.5050' },
    },
  ],
};

describe('CSV export', () => {
  it('has a BOM, exact money, quoting, and neutralizes formula injection', () => {
    const csv = toCsv(doc).toString('utf8');
    expect(csv.startsWith('﻿')).toBe(true);
    expect(csv).toContain('"Sales, ""goats""",45000.51');
    expect(csv).toContain(`"'=HYPERLINK(""http://evil"")",1.00`);
    expect(csv).toContain('دودھ کی فروخت,300.00');
    expect(csv).toContain('Total,45301.51');
  });
});

/** Reads one file out of the in-house ZIP, to check what Excel will see. */
function unzipEntry(buffer: Buffer, name: string): string {
  let offset = 0;
  while (buffer.readUInt32LE(offset) === 0x04034b50) {
    const compressedSize = buffer.readUInt32LE(offset + 18);
    const nameLength = buffer.readUInt16LE(offset + 26);
    const extraLength = buffer.readUInt16LE(offset + 28);
    const entryName = buffer.subarray(offset + 30, offset + 30 + nameLength).toString('utf8');
    const start = offset + 30 + nameLength + extraLength;
    if (entryName === name) return inflateRawSync(buffer.subarray(start, start + compressedSize)).toString('utf8');
    offset = start + compressedSize;
  }
  throw new Error(`missing ${name}`);
}

describe('XLSX export', () => {
  it('is a valid ZIP with workbook, styles and one sheet per section', () => {
    const xlsx = toXlsx(doc);
    expect(xlsx.subarray(0, 2).toString()).toBe('PK');
    expect(unzipEntry(xlsx, '[Content_Types].xml')).toContain('/xl/worksheets/sheet1.xml');
    expect(unzipEntry(xlsx, 'xl/workbook.xml')).toContain('<sheet name="Income"');
    const sheet = unzipEntry(xlsx, 'xl/worksheets/sheet1.xml');
    expect(sheet).toContain('<c r="B5" s="2"><v>45000.51</v></c>'); // money as a number, 2 dp, money format
    expect(sheet).toContain('Sales, &quot;goats&quot;'); // escaped text
    expect(sheet).toContain('دودھ کی فروخت'); // Urdu kept exactly
    expect(sheet).toContain('<c r="B8" s="3"><v>45301.51</v></c>'); // bold totals
  });

  it('column names go A..Z, AA..', () => {
    expect([0, 25, 26, 27, 701, 702].map(columnName)).toEqual(['A', 'Z', 'AA', 'AB', 'ZZ', 'AAA']);
  });
});

describe('PDF export', () => {
  it('produces a PDF document', async () => {
    const pdf = await toPdf(doc);
    expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
    expect(pdf.length).toBeGreaterThan(1000);
  });
});

describe('formatCell', () => {
  it('formats by type', () => {
    expect(formatCell('2026-11-04T10:20:30.000Z', 'datetime')).toBe('2026-11-04 10:20:30');
    expect(formatCell('66.7', 'percent')).toBe('66.7%');
    expect(formatCell(null, 'money')).toBe('');
  });
});
