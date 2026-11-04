import PDFDocument from 'pdfkit';
import { formatCell, type ReportDocument } from '../report-table.js';

const MARGIN = 40;
const ROW_HEIGHT = 16;

/** Characters the built-in PDF fonts can draw (Latin-1). */
const LATIN1 = /^[\u0000-ÿ]*$/;

/**
 * A4 PDF with each section as a simple table (landscape when a section has
 * many columns). Uses the standard Helvetica font, which only covers Latin
 * characters: text in other scripts (e.g. Urdu names) is replaced by "?"
 * with a note on the page; CSV and Excel exports keep such text exactly.
 */
export function toPdf(doc: ReportDocument): Promise<Buffer> {
  const wide = doc.sections.some((s) => s.columns.length > 5);
  const pdf = new PDFDocument({ size: 'A4', layout: wide ? 'landscape' : 'portrait', margin: MARGIN, bufferPages: true, info: { Title: doc.title, Producer: 'Tangent Smart Manager' } });
  const chunks: Buffer[] = [];
  pdf.on('data', (chunk: Buffer) => chunks.push(chunk));
  const done = new Promise<Buffer>((resolve, reject) => {
    pdf.on('end', () => resolve(Buffer.concat(chunks)));
    pdf.on('error', reject);
  });

  let replacedScript = false;
  const safe = (raw: string) => {
    // Typographic punctuation -> ASCII first; only genuinely unsupported scripts become "?".
    const text = raw
      .replace(/[–—]/g, '-')
      .replace(/[‘’]/g, "'")
      .replace(/[“”]/g, '"')
      .replace(/…/g, '...')
      .replace(/•/g, '*');
    if (LATIN1.test(text)) return text;
    replacedScript = true;
    return text.replace(/[^\u0000-ÿ]/g, '?');
  };

  const width = pdf.page.width - MARGIN * 2;
  pdf.font('Helvetica-Bold').fontSize(16).text(safe(doc.title));
  pdf.font('Helvetica').fontSize(10).fillColor('#555555').text(safe(`${doc.workspaceName} · ${doc.period}`));
  pdf.text(`Generated ${doc.generatedAt.toISOString().replace('T', ' ').slice(0, 16)} UTC`).fillColor('#000000');

  for (const section of doc.sections) {
    pdf.moveDown(1);
    if (pdf.y > pdf.page.height - MARGIN - ROW_HEIGHT * 4) pdf.addPage();
    pdf.font('Helvetica-Bold').fontSize(12).text(safe(section.title));
    pdf.moveDown(0.3);

    const textCols = section.columns.filter((c) => c.type === 'text').length;
    const numericWidth = Math.min(90, width / Math.max(section.columns.length, 1));
    const textWidth = textCols > 0 ? (width - numericWidth * (section.columns.length - textCols)) / textCols : 0;
    const colWidths = section.columns.map((c) => (c.type === 'text' ? textWidth : numericWidth));

    const headerCells = section.columns.map((c) => c.label);
    const drawRow = (cells: string[], bold: boolean, header = false): void => {
      if (pdf.y > pdf.page.height - MARGIN - ROW_HEIGHT) {
        pdf.addPage();
        // A table that continues on a new page repeats its column headers.
        if (!header) drawRow(headerCells, true, true);
      }
      const y = pdf.y;
      if (header) pdf.rect(MARGIN, y - 2, width, ROW_HEIGHT).fill('#EEF2F8').fillColor('#000000');
      let x = MARGIN;
      pdf.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(8.5);
      section.columns.forEach((column, i) => {
        const align = column.type === 'text' || column.type === 'date' || column.type === 'datetime' ? 'left' : 'right';
        pdf.text(safe(cells[i] ?? ''), x + 2, y + 2, { width: colWidths[i] - 4, align, lineBreak: false, ellipsis: true });
        x += colWidths[i];
      });
      pdf.x = MARGIN;
      pdf.y = y + ROW_HEIGHT;
    };

    drawRow(headerCells, true, true);
    if (section.rows.length === 0) {
      pdf.font('Helvetica-Oblique').fontSize(9).text('No data for this period.', MARGIN, pdf.y + 2);
      pdf.moveDown(0.5);
    }
    for (const row of section.rows) drawRow(section.columns.map((c) => formatMoneyForPdf(formatCell(row[c.key] ?? null, c.type), c.type)), false);
    if (section.totals) drawRow(section.columns.map((c) => formatMoneyForPdf(formatCell(section.totals![c.key] ?? null, c.type), c.type)), true);
  }

  if (replacedScript) {
    pdf.moveDown(1);
    pdf.font('Helvetica-Oblique').fontSize(8).fillColor('#555555').text('Some names use characters this PDF font cannot show (shown as "?"). The CSV and Excel exports contain them exactly.');
  }

  const range = pdf.bufferedPageRange();
  for (let i = range.start; i < range.start + range.count; i++) {
    pdf.switchToPage(i);
    // The footer sits inside the bottom margin; without lifting the margin
    // pdfkit treats it as overflow and appends a blank page.
    const bottom = pdf.page.margins.bottom;
    pdf.page.margins.bottom = 0;
    pdf.font('Helvetica').fontSize(8).fillColor('#888888').text(`Page ${i + 1} of ${range.count}`, MARGIN, pdf.page.height - MARGIN + 10, { width, align: 'right', lineBreak: false });
    pdf.page.margins.bottom = bottom;
  }
  pdf.end();
  return done;
}

/** Thousands separators for money in the PDF (the string is already exactly rounded). */
function formatMoneyForPdf(text: string, type: string): string {
  if (type !== 'money' || !/^-?\d+\.\d{2}$/.test(text)) return text;
  const negative = text.startsWith('-');
  const [whole, frac] = text.replace('-', '').split('.');
  return `${negative ? '-' : ''}${whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}.${frac}`;
}
