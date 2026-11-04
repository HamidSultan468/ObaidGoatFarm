import { crc32, deflateRawSync } from 'node:zlib';
import { formatCell, roundDecimalString, type ReportDocument, type ReportSection } from '../report-table.js';

/**
 * Minimal Office Open XML (.xlsx) writer: one worksheet per report section,
 * bold headers, number formats for money/decimals, frozen header row.
 * Written in-house (a ZIP of a few XML parts) to avoid a heavyweight
 * dependency; the format is the published ECMA-376 SpreadsheetML.
 *
 * Money cells are written as numbers rounded to 2 decimals from the exact
 * decimal string (Excel stores numbers as IEEE doubles; values up to
 * ~13 integer digits round-trip exactly at 2 decimals).
 */
export function toXlsx(doc: ReportDocument): Buffer {
  const sheets = doc.sections.length > 0 ? doc.sections : [{ title: 'Report', columns: [], rows: [] } as ReportSection];
  const names = uniqueSheetNames(sheets.map((s) => s.title));
  const files: Array<[string, string]> = [
    ['[Content_Types].xml', contentTypes(sheets.length)],
    ['_rels/.rels', ROOT_RELS],
    ['xl/workbook.xml', workbook(names)],
    ['xl/_rels/workbook.xml.rels', workbookRels(sheets.length)],
    ['xl/styles.xml', STYLES],
    ...sheets.map((section, i): [string, string] => [`xl/worksheets/sheet${i + 1}.xml`, worksheet(doc, section)]),
  ];
  return zip(files.map(([name, xml]) => ({ name, data: Buffer.from(xml, 'utf8') })));
}

const esc = (value: string) =>
  value
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

/** Excel sheet names: max 31 chars, no []:*?/\ and unique. */
function uniqueSheetNames(titles: string[]): string[] {
  const used = new Set<string>();
  return titles.map((title) => {
    const base = (title.replace(/[[\]:*?/\\]/g, ' ').trim() || 'Sheet').slice(0, 28);
    let name = base;
    for (let n = 2; used.has(name.toLowerCase()); n++) name = `${base.slice(0, 26)} ${n}`;
    used.add(name.toLowerCase());
    return name;
  });
}

/** Column letters: 0 -> A, 25 -> Z, 26 -> AA. */
export function columnName(index: number): string {
  let name = '';
  for (let n = index + 1; n > 0; n = Math.floor((n - 1) / 26)) name = String.fromCharCode(65 + ((n - 1) % 26)) + name;
  return name;
}

// Style ids from STYLES: 0 normal, 1 bold, 2 money (#,##0.00), 3 bold money, 4 title, 5 decimal (0.000)
function cellXml(ref: string, value: string | number | null, type: string, bold: boolean): string {
  if (value === null || value === undefined || value === '') return '';
  const numeric = type === 'money' || type === 'number' || type === 'decimal' || type === 'percent';
  if (numeric) {
    const text = type === 'money' ? roundDecimalString(String(value), 2) : String(value);
    if (/^-?\d+(\.\d+)?$/.test(text)) {
      const style = type === 'money' ? (bold ? 3 : 2) : type === 'decimal' ? 5 : bold ? 1 : 0;
      return `<c r="${ref}" s="${style}"><v>${text}</v></c>`;
    }
  }
  const shown = formatCell(value, type as never);
  return `<c r="${ref}" t="inlineStr"${bold ? ' s="1"' : ''}><is><t xml:space="preserve">${esc(shown)}</t></is></c>`;
}

function worksheet(doc: ReportDocument, section: ReportSection): string {
  const rows: string[] = [];
  const title = `<c r="A1" t="inlineStr" s="4"><is><t xml:space="preserve">${esc(`${doc.title} — ${section.title}`)}</t></is></c>`;
  rows.push(`<row r="1">${title}</row>`);
  rows.push(`<row r="2"><c r="A2" t="inlineStr"><is><t xml:space="preserve">${esc(`${doc.workspaceName} · ${doc.period}`)}</t></is></c></row>`);
  const headerRow = 4;
  rows.push(
    `<row r="${headerRow}">${section.columns
      .map((c, i) => `<c r="${columnName(i)}${headerRow}" t="inlineStr" s="1"><is><t xml:space="preserve">${esc(c.label)}</t></is></c>`)
      .join('')}</row>`,
  );
  const all = [...section.rows.map((r) => ({ row: r, bold: false })), ...(section.totals ? [{ row: section.totals, bold: true }] : [])];
  all.forEach(({ row, bold }, i) => {
    const r = headerRow + 1 + i;
    rows.push(`<row r="${r}">${section.columns.map((c, ci) => cellXml(`${columnName(ci)}${r}`, row[c.key] ?? null, c.type, bold)).join('')}</row>`);
  });
  const widths = section.columns
    .map((c, i) => `<col min="${i + 1}" max="${i + 1}" width="${c.type === 'text' ? 28 : c.type === 'datetime' ? 20 : 15}" customWidth="1"/>`)
    .join('');
  return (
    `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` +
    `<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">` +
    `<sheetViews><sheetView workbookViewId="0"><pane ySplit="${headerRow}" topLeftCell="A${headerRow + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>` +
    (widths ? `<cols>${widths}</cols>` : '') +
    `<sheetData>${rows.join('')}</sheetData></worksheet>`
  );
}

const contentTypes = (count: number) =>
  `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` +
  `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>` +
  `<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>` +
  `<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>` +
  Array.from({ length: count }, (_, i) => `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join('') +
  `</Types>`;

const ROOT_RELS =
  `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
  `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`;

const workbook = (names: string[]) =>
  `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>` +
  names.map((n, i) => `<sheet name="${esc(n)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join('') +
  `</sheets></workbook>`;

const workbookRels = (count: number) =>
  `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` +
  Array.from({ length: count }, (_, i) => `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join('') +
  `<Relationship Id="rId${count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`;

const STYLES =
  `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">` +
  `<numFmts count="2"><numFmt numFmtId="164" formatCode="#,##0.00"/><numFmt numFmtId="165" formatCode="0.000"/></numFmts>` +
  `<fonts count="3"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="14"/><name val="Calibri"/></font></fonts>` +
  `<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>` +
  `<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>` +
  `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>` +
  `<cellXfs count="6"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>` +
  `<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>` +
  `<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>` +
  `<xf numFmtId="164" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>` +
  `<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>` +
  `<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>` +
  `<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>` +
  `</styleSheet>`;

/** ZIP container (deflate) with a central directory — what every .xlsx reader expects. */
export function zip(entries: Array<{ name: string; data: Buffer }>): Buffer {
  const locals: Buffer[] = [];
  const centrals: Buffer[] = [];
  let offset = 0;
  // Fixed DOS timestamp (1980-01-01) keeps output deterministic.
  const dosTime = 0;
  const dosDate = (0 << 9) | (1 << 5) | 1;
  for (const entry of entries) {
    const name = Buffer.from(entry.name, 'utf8');
    const compressed = deflateRawSync(entry.data);
    const crc = crc32(entry.data) >>> 0;
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6); // UTF-8 names
    local.writeUInt16LE(8, 8); // deflate
    local.writeUInt16LE(dosTime, 10);
    local.writeUInt16LE(dosDate, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(compressed.length, 18);
    local.writeUInt32LE(entry.data.length, 22);
    local.writeUInt16LE(name.length, 26);
    local.writeUInt16LE(0, 28);
    locals.push(local, name, compressed);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0x0800, 8);
    central.writeUInt16LE(8, 10);
    central.writeUInt16LE(dosTime, 12);
    central.writeUInt16LE(dosDate, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(compressed.length, 20);
    central.writeUInt32LE(entry.data.length, 24);
    central.writeUInt16LE(name.length, 28);
    central.writeUInt32LE(offset, 42);
    centrals.push(central, name);
    offset += 30 + name.length + compressed.length;
  }
  const centralSize = centrals.reduce((n, b) => n + b.length, 0);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, ...centrals, end]);
}
