import type { ConfigService } from '@nestjs/config';
import { describe, expect, it } from 'vitest';
import { EncryptionService } from './encryption.service.js';

const config = { getOrThrow: () => 'ab'.repeat(32) } as unknown as ConfigService;
const service = new EncryptionService(config);

describe('EncryptionService', () => {
  it('round-trips strings with a fresh IV each time', () => {
    const a = service.encrypt('secret');
    const b = service.encrypt('secret');
    expect(a).not.toBe(b);
    expect(service.decrypt(a)).toBe('secret');
  });

  it('round-trips binary file contents', () => {
    const file = Buffer.from([0x25, 0x50, 0x44, 0x46, 0x00, 0xff, 0x10]);
    const encrypted = service.encryptBuffer(file);
    expect(encrypted.includes(file)).toBe(false);
    expect(service.decryptBuffer(encrypted).equals(file)).toBe(true);
  });

  it('rejects tampered ciphertext (GCM auth tag)', () => {
    const encrypted = service.encryptBuffer(Buffer.from('ledger receipt'));
    encrypted[encrypted.length - 1] ^= 0x01;
    expect(() => service.decryptBuffer(encrypted)).toThrow();
  });

  it('rejects a payload too short to contain IV and tag', () => {
    expect(() => service.decryptBuffer(Buffer.alloc(10))).toThrow('Malformed encrypted payload');
  });

  it('rejects a key of the wrong length', () => {
    const badConfig = { getOrThrow: () => 'abcd' } as unknown as ConfigService;
    expect(() => new EncryptionService(badConfig)).toThrow();
  });
});
