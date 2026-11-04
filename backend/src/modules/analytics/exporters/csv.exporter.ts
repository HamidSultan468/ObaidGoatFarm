import { formatCell, type ReportDocument } from '../report-table.js';

/** Quotes a CSV field; prefixes formula-like text so spreadsheets don't execute it (CSV injection). */
function field(value: string): string {
  const safe = /^[=+\-@\t\r]/.test(value) && !/^-?\d+(\.\d+)?$/.test(value) ? `'${value}` : value;
  return /[",\r\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
}

/**
 * UTF-8 CSV with a BOM (so Excel opens Urdu text correctly). Sections are
 * separated by a blank line and headed by their title. Money is exact,
 * 2 decimals, no thousands separators.
 */
export function toCsv(doc: ReportDocument): Buffer {
  const lines: string[] = [
    field(doc.title),
    field(`${doc.workspaceName} · ${doc.period}`),
    field(`Generated ${doc.generatedAt.toISOString().replace('T', ' ').slice(0, 19)} UTC`),
  ];
  for (const section of doc.sections) {
    lines.push('', field(section.title), section.columns.map((c) => field(c.label)).join(','));
    for (const row of [...section.rows, ...(section.totals ? [section.totals] : [])]) {
      lines.push(section.columns.map((c) => field(formatCell(row[c.key] ?? null, c.type))).join(','));
    }
  }
  return Buffer.from(`﻿${lines.join('\r\n')}\r\n`, 'utf8');
}
