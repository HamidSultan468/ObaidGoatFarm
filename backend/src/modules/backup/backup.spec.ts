import { describe, expect, it } from 'vitest';
import { BackupFileError, decryptBackup, deriveBackupKey, encryptBackup } from './backup-cipher.js';
import { BACKUP_FORMAT, BACKUP_FORMAT_VERSION, validateBackupPayload } from './backup-format.js';

const MASTER = 'ab'.repeat(32);

describe('backup cipher', () => {
  const key = deriveBackupKey(MASTER);

  it('round-trips and never contains the plaintext', () => {
    const plain = Buffer.from('{"secret":"ledger"}');
    const file = encryptBackup(plain, key);
    expect(file.subarray(0, 4).toString()).toBe('TSMB');
    expect(file.includes(plain)).toBe(false);
    expect(decryptBackup(file, key).equals(plain)).toBe(true);
  });

  it('derives a key different from the master key (key separation)', () => {
    expect(key.equals(Buffer.from(MASTER, 'hex'))).toBe(false);
    expect(deriveBackupKey(MASTER).equals(key)).toBe(true);
  });

  it('rejects a modified file, a foreign key, and non-backup files', () => {
    const file = encryptBackup(Buffer.from('data'), key);
    const tampered = Buffer.from(file);
    tampered[tampered.length - 1] ^= 1;
    expect(() => decryptBackup(tampered, key)).toThrow(BackupFileError);
    expect(() => decryptBackup(file, deriveBackupKey('cd'.repeat(32)))).toThrow(/different server|modified/);
    expect(() => decryptBackup(Buffer.from('%PDF-1.7 not a backup at all......'), key)).toThrow(/not a Tangent backup/);
  });
});

function payload(overrides: Record<string, unknown> = {}) {
  return {
    format: BACKUP_FORMAT,
    version: BACKUP_FORMAT_VERSION,
    createdAt: '2026-11-04T00:00:00.000Z',
    workspace: { id: 'w1', name: 'Farm', slug: 'farm', approvalThreshold: null, backupRetention: 7 },
    data: {
      accounts: [{ id: 'cash' }, { id: 'sales' }],
      contacts: [],
      journalEntries: [
        { id: 'e1', contactId: null, animalId: 'a1', landParcelId: null, reversalOfId: null, lines: [{ id: 'l1', accountId: 'cash', amount: '0.1000' }, { id: 'l2', accountId: 'sales', amount: '-0.1000' }] },
      ],
      recurringTemplates: [],
      budgets: [],
      animals: [{ id: 'a1', sireId: null, damId: null }],
      animalHealthRecords: [{ id: 'h1', animalId: 'a1' }],
      animalWeightRecords: [],
      breedingRecords: [],
      landParcels: [],
      attachments: [{ id: 'f1', module: 'ANIMAL', recordId: 'a1', content: 'JVBERi0=' }],
      ...overrides,
    },
  };
}

describe('validateBackupPayload', () => {
  it('accepts a consistent backup and reports counts', () => {
    const result = validateBackupPayload(payload());
    expect(result.errors).toEqual([]);
    expect(result.valid).toBe(true);
    expect(result.counts).toMatchObject({ accounts: 2, journalEntries: 1, animals: 1, attachments: 1 });
  });

  it('rejects an unbalanced journal entry (exact decimal check)', () => {
    const bad = payload({
      journalEntries: [{ id: 'e1', lines: [{ id: 'l1', accountId: 'cash', amount: '100.00' }, { id: 'l2', accountId: 'sales', amount: '-99.99' }] }],
    });
    const result = validateBackupPayload(bad);
    expect(result.valid).toBe(false);
    expect(result.errors.join()).toMatch(/does not balance \(off by 0\.0100\)/);
  });

  it('rejects references to rows that are not in the backup', () => {
    const bad = payload({ animalHealthRecords: [{ id: 'h1', animalId: 'ghost' }], attachments: [{ id: 'f1', module: 'LAND', recordId: 'nope', content: 'x' }] });
    const result = validateBackupPayload(bad);
    expect(result.errors.join()).toMatch(/missing animal/);
    expect(result.errors.join()).toMatch(/missing LAND record/);
  });

  it('rejects wrong format, wrong version and missing tables', () => {
    expect(validateBackupPayload({ format: 'other' }).valid).toBe(false);
    expect(validateBackupPayload({ ...payload(), version: 99 }).errors[0]).toMatch(/version 99/);
    const missing = payload();
    delete (missing.data as Record<string, unknown>).budgets;
    expect(validateBackupPayload(missing).errors[0]).toMatch(/missing the budgets table/);
  });

  it('rejects duplicate ids', () => {
    const result = validateBackupPayload(payload({ accounts: [{ id: 'cash' }, { id: 'cash' }, { id: 'sales' }] }));
    expect(result.errors.join()).toMatch(/duplicate id cash/);
  });
});
