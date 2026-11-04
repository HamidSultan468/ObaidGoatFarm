import { Money } from '../../common/money/money.js';

export const BACKUP_FORMAT = 'tangent-smart-manager-backup';
export const BACKUP_FORMAT_VERSION = 1;

type Row = Record<string, unknown> & { id: string };

/**
 * Everything a workspace owns. Rows are the database rows as JSON (dates as
 * ISO strings, decimals as strings). Users, password hashes, MFA secrets,
 * sessions and notifications are deliberately NOT included.
 */
export interface BackupPayload {
  format: typeof BACKUP_FORMAT;
  version: number;
  createdAt: string;
  workspace: { id: string; name: string; slug: string; approvalThreshold: string | null; backupRetention: number };
  data: {
    accounts: Row[];
    contacts: Row[];
    journalEntries: Array<Row & { lines: Row[] }>;
    recurringTemplates: Row[];
    budgets: Row[];
    animals: Row[];
    animalHealthRecords: Row[];
    animalWeightRecords: Row[];
    breedingRecords: Row[];
    landParcels: Row[];
    /** `content` is the decrypted file, base64. */
    attachments: Array<Row & { content: string }>;
  };
}

export const DATA_KEYS = [
  'accounts',
  'contacts',
  'journalEntries',
  'recurringTemplates',
  'budgets',
  'animals',
  'animalHealthRecords',
  'animalWeightRecords',
  'breedingRecords',
  'landParcels',
  'attachments',
] as const;

export type BackupCounts = Record<(typeof DATA_KEYS)[number], number>;

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  counts: BackupCounts | null;
}

const isObject = (value: unknown): value is Record<string, unknown> => typeof value === 'object' && value !== null && !Array.isArray(value);

/**
 * Full structural check before anything is restored: format and version,
 * every table present, ids unique, every reference points at a row in the
 * same backup, and every journal entry balances to exactly zero. A restore
 * must never start on a backup that fails any of these.
 */
export function validateBackupPayload(payload: unknown): ValidationResult {
  const errors: string[] = [];
  const fail = (message: string): ValidationResult => ({ valid: false, errors: [...errors, message], counts: null });

  if (!isObject(payload)) return fail('Backup content is not an object');
  if (payload.format !== BACKUP_FORMAT) return fail('Not a Tangent Smart Manager backup');
  if (payload.version !== BACKUP_FORMAT_VERSION) return fail(`Unsupported backup format version ${String(payload.version)}`);
  if (!isObject(payload.workspace) || typeof payload.workspace.id !== 'string' || typeof payload.workspace.name !== 'string') {
    return fail('Backup has no workspace information');
  }
  if (!isObject(payload.data)) return fail('Backup has no data section');

  const data = payload.data as Record<string, unknown>;
  for (const key of DATA_KEYS) {
    if (!Array.isArray(data[key])) return fail(`Backup is missing the ${key} table`);
  }
  const d = data as unknown as BackupPayload['data'];

  const ids = new Map<string, Set<string>>();
  for (const key of DATA_KEYS) {
    const set = new Set<string>();
    for (const row of d[key] as Row[]) {
      if (!isObject(row) || typeof row.id !== 'string') {
        errors.push(`${key}: a row has no id`);
        continue;
      }
      if (set.has(row.id)) errors.push(`${key}: duplicate id ${row.id}`);
      set.add(row.id);
    }
    ids.set(key, set);
  }
  const has = (table: (typeof DATA_KEYS)[number], id: unknown) => typeof id === 'string' && ids.get(table)!.has(id);
  const optionalRef = (table: (typeof DATA_KEYS)[number], id: unknown, where: string) => {
    if (id !== null && id !== undefined && !has(table, id)) errors.push(`${where} points at a missing ${table} row`);
  };

  for (const entry of d.journalEntries) {
    if (!Array.isArray(entry.lines) || entry.lines.length < 2) {
      errors.push(`journal entry ${entry.id} has fewer than two lines`);
      continue;
    }
    try {
      const total = Money.sum(entry.lines.map((line) => Money.from(String(line.amount))));
      if (!total.isZero()) errors.push(`journal entry ${entry.id} does not balance (off by ${total.toFixed(4)})`);
    } catch {
      errors.push(`journal entry ${entry.id} has an invalid amount`);
    }
    for (const line of entry.lines) {
      if (!has('accounts', line.accountId)) errors.push(`journal entry ${entry.id} uses a missing account`);
    }
    optionalRef('contacts', entry.contactId, `journal entry ${entry.id}`);
    optionalRef('animals', entry.animalId, `journal entry ${entry.id}`);
    optionalRef('landParcels', entry.landParcelId, `journal entry ${entry.id}`);
    optionalRef('journalEntries', entry.reversalOfId, `journal entry ${entry.id}`);
  }
  for (const animal of d.animals) {
    optionalRef('animals', animal.sireId, `animal ${animal.id} sire`);
    optionalRef('animals', animal.damId, `animal ${animal.id} dam`);
  }
  for (const row of [...d.animalHealthRecords, ...d.animalWeightRecords]) {
    if (!has('animals', row.animalId)) errors.push(`record ${row.id} belongs to a missing animal`);
  }
  for (const row of d.breedingRecords) {
    if (!has('animals', row.damId)) errors.push(`breeding record ${row.id} has a missing dam`);
    optionalRef('animals', row.sireId, `breeding record ${row.id} sire`);
  }
  for (const row of d.landParcels) optionalRef('contacts', row.counterpartyContactId, `land parcel ${row.id}`);
  for (const row of d.budgets) {
    if (!has('accounts', row.accountId)) errors.push(`budget ${row.id} uses a missing account`);
  }
  for (const row of d.recurringTemplates) {
    if (!has('accounts', row.fromAccountId) || !has('accounts', row.toAccountId)) errors.push(`recurring template ${row.id} uses a missing account`);
    optionalRef('contacts', row.contactId, `recurring template ${row.id}`);
  }
  const moduleTable: Record<string, (typeof DATA_KEYS)[number]> = {
    ANIMAL: 'animals',
    LAND: 'landParcels',
    TRANSACTION: 'journalEntries',
    CONTACT: 'contacts',
  };
  for (const row of d.attachments) {
    if (typeof row.content !== 'string') errors.push(`attachment ${row.id} has no file content`);
    if (row.module !== 'GENERAL' && !has(moduleTable[String(row.module)], row.recordId)) {
      errors.push(`attachment ${row.id} belongs to a missing ${String(row.module)} record`);
    }
  }

  const counts = Object.fromEntries(DATA_KEYS.map((key) => [key, (d[key] as Row[]).length])) as BackupCounts;
  return { valid: errors.length === 0, errors: errors.slice(0, 50), counts };
}
