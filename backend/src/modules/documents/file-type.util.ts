/** Upload limit for a single document (10 MB). */
export const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;

export type AllowedMimeType = 'image/jpeg' | 'image/png' | 'image/webp' | 'application/pdf';

const startsWith = (buffer: Buffer, bytes: number[], offset = 0) =>
  buffer.length >= offset + bytes.length && bytes.every((byte, i) => buffer[offset + i] === byte);

/**
 * Detects the real file type from its leading bytes. The client-supplied
 * Content-Type is never trusted: a renamed .exe claiming to be image/png is
 * rejected because its bytes don't match. Returns null for anything that
 * isn't one of the allowed types.
 */
export function sniffMimeType(buffer: Buffer): AllowedMimeType | null {
  if (startsWith(buffer, [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (startsWith(buffer, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return 'image/png';
  if (startsWith(buffer, [0x52, 0x49, 0x46, 0x46]) && startsWith(buffer, [0x57, 0x45, 0x42, 0x50], 8)) return 'image/webp';
  if (startsWith(buffer, [0x25, 0x50, 0x44, 0x46, 0x2d])) return 'application/pdf';
  return null;
}

/**
 * A safe display/download name: strips any path, control and quote
 * characters (header injection), collapses whitespace, caps the length.
 */
export function sanitizeFileName(name: string): string {
  const base = name.split(/[\\/]/).pop() ?? '';
  const cleaned = base
    .replace(/[\u0000-\u001f\u007f"<>|:*?]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 150);
  return cleaned.length > 0 && cleaned !== '.' && cleaned !== '..' ? cleaned : 'document';
}

/** RFC 6266 Content-Disposition with an ASCII fallback and a UTF-8 filename*. */
export function contentDisposition(fileName: string, inline: boolean): string {
  const asciiFallback = fileName.replace(/[^\x20-\x7e]/g, '_').replace(/[\\]/g, '_');
  return `${inline ? 'inline' : 'attachment'}; filename="${asciiFallback}"; filename*=UTF-8''${encodeURIComponent(fileName)}`;
}
