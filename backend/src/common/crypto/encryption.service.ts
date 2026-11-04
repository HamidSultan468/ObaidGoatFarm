import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;
const KEY_LENGTH = 32;
const AUTH_TAG_LENGTH = 16;

/**
 * Centralized AES-256-GCM encryption for secrets that must be stored at
 * rest but recovered in plaintext later (e.g. an MFA TOTP secret) — as
 * opposed to passwords/refresh tokens, which are one-way hashed and never
 * need decrypting. Every encrypted value gets its own random IV, stored
 * alongside the ciphertext and auth tag.
 */
@Injectable()
export class EncryptionService {
  private readonly key: Buffer;

  constructor(configService: ConfigService) {
    const hexKey = configService.getOrThrow<string>('encryptionKey');
    const key = Buffer.from(hexKey, 'hex');
    if (key.length !== KEY_LENGTH) {
      throw new Error(`ENCRYPTION_KEY must be a ${KEY_LENGTH * 2}-character hex string (${KEY_LENGTH} bytes)`);
    }
    this.key = key;
  }

  /** Returns `iv:authTag:ciphertext`, all hex-encoded. */
  encrypt(plaintext: string): string {
    const iv = randomBytes(IV_LENGTH);
    const cipher = createCipheriv(ALGORITHM, this.key, iv);
    const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
    const authTag = cipher.getAuthTag();
    return `${iv.toString('hex')}:${authTag.toString('hex')}:${ciphertext.toString('hex')}`;
  }

  /** Binary variant for file contents: returns `iv (12) | authTag (16) | ciphertext`. */
  encryptBuffer(plaintext: Buffer): Buffer {
    const iv = randomBytes(IV_LENGTH);
    const cipher = createCipheriv(ALGORITHM, this.key, iv);
    const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]);
  }

  /** Throws if the data was tampered with (GCM auth tag mismatch). */
  decryptBuffer(payload: Buffer): Buffer {
    if (payload.length < IV_LENGTH + AUTH_TAG_LENGTH) {
      throw new Error('Malformed encrypted payload');
    }
    const iv = payload.subarray(0, IV_LENGTH);
    const authTag = payload.subarray(IV_LENGTH, IV_LENGTH + AUTH_TAG_LENGTH);
    const decipher = createDecipheriv(ALGORITHM, this.key, iv);
    decipher.setAuthTag(authTag);
    return Buffer.concat([decipher.update(payload.subarray(IV_LENGTH + AUTH_TAG_LENGTH)), decipher.final()]);
  }

  decrypt(payload: string): string {
    const [ivHex, authTagHex, ciphertextHex] = payload.split(':');
    if (!ivHex || !authTagHex || !ciphertextHex) {
      throw new Error('Malformed encrypted payload');
    }

    const decipher = createDecipheriv(ALGORITHM, this.key, Buffer.from(ivHex, 'hex'));
    decipher.setAuthTag(Buffer.from(authTagHex, 'hex'));
    const plaintext = Buffer.concat([decipher.update(Buffer.from(ciphertextHex, 'hex')), decipher.final()]);
    return plaintext.toString('utf8');
  }
}
