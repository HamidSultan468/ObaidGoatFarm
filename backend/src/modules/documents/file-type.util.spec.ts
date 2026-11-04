import { describe, expect, it } from 'vitest';
import { contentDisposition, sanitizeFileName, sniffMimeType } from './file-type.util.js';

const bytes = (...values: number[]) => Buffer.from(values);

describe('sniffMimeType', () => {
  it('recognizes the allowed types by their magic bytes', () => {
    expect(sniffMimeType(bytes(0xff, 0xd8, 0xff, 0xe0, 0x00))).toBe('image/jpeg');
    expect(sniffMimeType(bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00))).toBe('image/png');
    expect(sniffMimeType(Buffer.concat([Buffer.from('RIFF'), bytes(0, 0, 0, 0), Buffer.from('WEBPVP8 ')]))).toBe('image/webp');
    expect(sniffMimeType(Buffer.from('%PDF-1.7\n'))).toBe('application/pdf');
  });

  it('rejects executables, HTML/SVG (script carriers) and empty files', () => {
    expect(sniffMimeType(Buffer.from('MZ\x90\x00'))).toBeNull();
    expect(sniffMimeType(Buffer.from('<html><script>'))).toBeNull();
    expect(sniffMimeType(Buffer.from('<svg xmlns='))).toBeNull();
    expect(sniffMimeType(Buffer.alloc(0))).toBeNull();
  });

  it('rejects a RIFF file that is not WEBP (e.g. WAV)', () => {
    expect(sniffMimeType(Buffer.concat([Buffer.from('RIFF'), bytes(0, 0, 0, 0), Buffer.from('WAVE')]))).toBeNull();
  });
});

describe('sanitizeFileName', () => {
  it('strips directories (path traversal) from the name', () => {
    expect(sanitizeFileName('../../etc/passwd')).toBe('passwd');
    expect(sanitizeFileName('C:\\Users\\me\\receipt.pdf')).toBe('receipt.pdf');
  });

  it('removes quotes and control characters that could break headers', () => {
    expect(sanitizeFileName('bad"\r\nname.pdf')).toBe('badname.pdf');
  });

  it('keeps Urdu names and falls back when nothing is left', () => {
    expect(sanitizeFileName('رسید.pdf')).toBe('رسید.pdf');
    expect(sanitizeFileName('..')).toBe('document');
    expect(sanitizeFileName('')).toBe('document');
  });
});

describe('contentDisposition', () => {
  it('gives an ASCII fallback plus the exact UTF-8 name', () => {
    expect(contentDisposition('رسید.pdf', false)).toBe(
      `attachment; filename="____.pdf"; filename*=UTF-8''${encodeURIComponent('رسید.pdf')}`,
    );
    expect(contentDisposition('photo.jpg', true)).toBe(`inline; filename="photo.jpg"; filename*=UTF-8''photo.jpg`);
  });
});
