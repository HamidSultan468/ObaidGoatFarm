import { createHash, createHmac, randomInt, timingSafeEqual } from 'node:crypto';

/**
 * Meta signs every webhook POST with `X-Hub-Signature-256: sha256=<hex>`,
 * an HMAC-SHA256 of the exact raw body using the app secret. Compared in
 * constant time; any malformed header fails.
 */
export function isValidSignature(appSecret: string, rawBody: Buffer, header: string | undefined): boolean {
  if (!header || !header.startsWith('sha256=')) return false;
  const received = Buffer.from(header.slice('sha256='.length), 'hex');
  const expected = createHmac('sha256', appSecret).update(rawBody).digest();
  return received.length === expected.length && timingSafeEqual(received, expected);
}

/**
 * E.164 with a leading "+". Accepts Meta's digits-only `from`, "+92 300
 * 1234567", or a local Pakistani "0300..." number (default country 92).
 * Returns null for anything that can't be a phone number.
 */
export function normalizePhone(raw: string, defaultCountryCode = '92'): string | null {
  let digits = raw.replace(/[\s\-()]/g, '');
  if (digits.startsWith('+')) digits = digits.slice(1);
  else if (digits.startsWith('00')) digits = digits.slice(2);
  else if (digits.startsWith('0')) digits = defaultCountryCode + digits.slice(1);
  if (!/^\d{8,15}$/.test(digits)) return null;
  return `+${digits}`;
}

export type WhatsAppCommand = { type: 'link'; code: string } | { type: 'help' } | { type: 'text'; text: string };

export function parseCommand(body: string): WhatsAppCommand {
  const text = body.trim();
  const link = /^link\s+(\d{6})$/i.exec(text);
  if (link) return { type: 'link', code: link[1] };
  if (/^(help|madad)$/i.test(text)) return { type: 'help' };
  return { type: 'text', text };
}

/** 6-digit one-time code and its stored hash (the code itself is never stored). */
export function newLinkCode(): { code: string; hash: string } {
  const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
  return { code, hash: hashLinkCode(code) };
}

export function hashLinkCode(code: string): string {
  return createHash('sha256').update(`whatsapp-link:${code}`).digest('hex');
}

export const HELP_TEXT =
  'Tangent Smart Manager: send what happened in one message, e.g. "2 bakriyan 90 hazar me bechi" or "Sultan ka wazan 42 kg". ' +
  'A draft is created in the app and is saved only after someone approves it.';
