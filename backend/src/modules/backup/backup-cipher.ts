import { createCipheriv, createDecipheriv, hkdfSync, randomBytes } from 'node:crypto';

/** File signature + format byte, so a wrong/foreign file is rejected immediately. */
const MAGIC = Buffer.from('TSMB', 'ascii');
const FILE_VERSION = 1;
const IV_LENGTH = 12;
const TAG_LENGTH = 16;
const HEADER_LENGTH = MAGIC.length + 1 + IV_LENGTH + TAG_LENGTH;

/**
 * A key used only for backups, derived from the master ENCRYPTION_KEY with
 * HKDF. Key separation: a backup key can never decrypt MFA secrets or
 * attachments directly, and vice versa.
 */
export function deriveBackupKey(masterKeyHex: string): Buffer {
  return Buffer.from(hkdfSync('sha256', Buffer.from(masterKeyHex, 'hex'), Buffer.alloc(0), 'tangent-backup-v1', 32));
}

/** `TSMB | version | iv | authTag | AES-256-GCM(ciphertext)`. */
export function encryptBackup(plaintext: Buffer, key: Buffer): Buffer {
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  cipher.setAAD(MAGIC);
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return Buffer.concat([MAGIC, Buffer.from([FILE_VERSION]), iv, cipher.getAuthTag(), ciphertext]);
}

export class BackupFileError extends Error {}

/** Throws BackupFileError if the file is not a backup, is an unknown version, or was altered. */
export function decryptBackup(file: Buffer, key: Buffer): Buffer {
  if (file.length < HEADER_LENGTH || !file.subarray(0, MAGIC.length).equals(MAGIC)) {
    throw new BackupFileError('This is not a Tangent backup file');
  }
  const version = file[MAGIC.length];
  if (version !== FILE_VERSION) {
    throw new BackupFileError(`Unsupported backup file version ${version}`);
  }
  let offset = MAGIC.length + 1;
  const iv = file.subarray(offset, (offset += IV_LENGTH));
  const tag = file.subarray(offset, (offset += TAG_LENGTH));
  try {
    const decipher = createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAAD(MAGIC);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(file.subarray(offset)), decipher.final()]);
  } catch {
    throw new BackupFileError('The backup file is damaged, was modified, or belongs to a different server');
  }
}
