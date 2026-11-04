import { createHmac } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { hashLinkCode, isValidSignature, newLinkCode, normalizePhone, parseCommand } from './whatsapp.util.js';

describe('isValidSignature', () => {
  const secret = 'app-secret-123';
  const body = Buffer.from('{"object":"whatsapp_business_account"}');
  const sign = (b: Buffer, s = secret) => `sha256=${createHmac('sha256', s).update(b).digest('hex')}`;

  it('accepts the exact body signed with the app secret', () => {
    expect(isValidSignature(secret, body, sign(body))).toBe(true);
  });

  it('rejects a modified body, another secret, or a malformed header', () => {
    expect(isValidSignature(secret, Buffer.from('{"object":"x"}'), sign(body))).toBe(false);
    expect(isValidSignature(secret, body, sign(body, 'other-secret'))).toBe(false);
    expect(isValidSignature(secret, body, undefined)).toBe(false);
    expect(isValidSignature(secret, body, 'sha1=abc')).toBe(false);
    expect(isValidSignature(secret, body, 'sha256=zz')).toBe(false);
  });
});

describe('normalizePhone', () => {
  it('normalizes common formats to E.164', () => {
    expect(normalizePhone('923001234567')).toBe('+923001234567');
    expect(normalizePhone('+92 300 123-4567')).toBe('+923001234567');
    expect(normalizePhone('03001234567')).toBe('+923001234567');
    expect(normalizePhone('00923001234567')).toBe('+923001234567');
  });

  it('rejects things that are not phone numbers', () => {
    expect(normalizePhone('hello')).toBeNull();
    expect(normalizePhone('123')).toBeNull();
  });
});

describe('parseCommand', () => {
  it('recognizes LINK with a 6-digit code (any case) and HELP', () => {
    expect(parseCommand(' link 042137 ')).toEqual({ type: 'link', code: '042137' });
    expect(parseCommand('HELP')).toEqual({ type: 'help' });
    expect(parseCommand('madad')).toEqual({ type: 'help' });
  });

  it('treats anything else as free text for a draft', () => {
    expect(parseCommand('LINK 12345')).toEqual({ type: 'text', text: 'LINK 12345' });
    expect(parseCommand('2 bakriyan 90 hazar me bechi')).toEqual({ type: 'text', text: '2 bakriyan 90 hazar me bechi' });
  });
});

describe('link codes', () => {
  it('are 6 digits and only their hash is stored', () => {
    const { code, hash } = newLinkCode();
    expect(code).toMatch(/^\d{6}$/);
    expect(hash).toBe(hashLinkCode(code));
    expect(hash).not.toContain(code);
  });
});
