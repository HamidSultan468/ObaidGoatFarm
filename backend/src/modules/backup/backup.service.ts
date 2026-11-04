import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { BackupTrigger, Prisma } from '@prisma/client';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import { gunzip, gzip } from 'node:zlib';
import { PrismaService } from '../../prisma/prisma.service.js';
import { DocumentsService } from '../documents/documents.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { BackupFileError, decryptBackup, deriveBackupKey, encryptBackup } from './backup-cipher.js';
import {
  BACKUP_FORMAT,
  BACKUP_FORMAT_VERSION,
  validateBackupPayload,
  type BackupPayload,
  type ValidationResult,
} from './backup-format.js';
import { BACKUP_STORAGE_PROVIDER, type BackupStorageProvider } from './storage/backup-storage.provider.js';

const gzipAsync = promisify(gzip);
const gunzipAsync = promisify(gunzip);

/** Restores can be large; give the single transaction room to finish. */
const RESTORE_TRANSACTION_TIMEOUT_MS = 5 * 60_000;

/** Fields safe to return to clients (never the storage key). */
const PUBLIC_FIELDS = {
  id: true,
  trigger: true,
  status: true,
  provider: true,
  sizeBytes: true,
  formatVersion: true,
  counts: true,
  error: true,
  createdByUserId: true,
  startedAt: true,
  completedAt: true,
} as const;

/** JSON round-trip turns Dates into ISO strings and Prisma Decimals into strings. */
const toPlain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T;

@Injectable()
export class BackupService {
  private readonly logger = new Logger(BackupService.name);
  private readonly key: Buffer;

  constructor(
    private readonly prisma: PrismaService,
    private readonly documents: DocumentsService,
    private readonly notifications: NotificationsService,
    @Inject(BACKUP_STORAGE_PROVIDER) private readonly storage: BackupStorageProvider,
    config: ConfigService,
  ) {
    this.key = deriveBackupKey(config.getOrThrow<string>('encryptionKey'));
  }

  // --- Create -----------------------------------------------------------------

  async createBackup(workspaceId: string, trigger: BackupTrigger, userId?: string) {
    const backup = await this.prisma.backup.create({
      data: { workspaceId, trigger, provider: this.storage.id, createdByUserId: userId },
    });
    try {
      const payload = await this.snapshot(workspaceId);
      const check = validateBackupPayload(payload);
      if (!check.valid) {
        // The live data itself is inconsistent; refuse to write a backup that couldn't be restored.
        throw new Error(`Workspace data failed validation: ${check.errors.slice(0, 3).join('; ')}`);
      }
      const file = encryptBackup(await gzipAsync(Buffer.from(JSON.stringify(payload))), this.key);
      const storageKey = `${workspaceId}/${backup.id}.tsmbak`;
      await this.storage.put(storageKey, file);
      return await this.prisma.backup.update({
        where: { id: backup.id },
        data: {
          status: 'COMPLETED',
          storageKey,
          sizeBytes: file.length,
          sha256: createHash('sha256').update(file).digest('hex'),
          formatVersion: BACKUP_FORMAT_VERSION,
          counts: check.counts as unknown as Prisma.InputJsonValue,
          completedAt: new Date(),
        },
        select: PUBLIC_FIELDS,
      });
    } catch (error) {
      const message = (error as Error).message.slice(0, 500);
      this.logger.error(`Backup ${backup.id} for workspace ${workspaceId} failed: ${message}`);
      await this.prisma.backup.update({ where: { id: backup.id }, data: { status: 'FAILED', error: message, completedAt: new Date() } });
      await this.notifications.notifyByRule(workspaceId, {
        category: 'BACKUP',
        severity: 'CRITICAL',
        title: 'Backup failed',
        body: `The ${trigger === 'SCHEDULED' ? 'daily' : 'manual'} backup could not be completed: ${message}`,
        link: '/settings',
      });
      throw new InternalServerErrorException('The backup could not be completed. See the backup list for details.');
    }
  }

  /** Every row the workspace owns, plus decrypted attachment bytes. */
  private async snapshot(workspaceId: string): Promise<BackupPayload> {
    const where = { workspaceId };
    const [workspace, accounts, contacts, journalEntries, recurringTemplates, budgets, animals, health, weights, breeding, land, attachments] =
      await Promise.all([
        this.prisma.workspace.findUniqueOrThrow({ where: { id: workspaceId } }),
        this.prisma.account.findMany({ where }),
        this.prisma.contact.findMany({ where }),
        this.prisma.journalEntry.findMany({ where, include: { lines: true }, orderBy: { createdAt: 'asc' } }),
        this.prisma.recurringTemplate.findMany({ where }),
        this.prisma.budget.findMany({ where }),
        this.prisma.animal.findMany({ where }),
        this.prisma.animalHealthRecord.findMany({ where }),
        this.prisma.animalWeightRecord.findMany({ where }),
        this.prisma.breedingRecord.findMany({ where }),
        this.prisma.landParcel.findMany({ where }),
        this.prisma.attachment.findMany({ where }),
      ]);

    const attachmentRows: BackupPayload['data']['attachments'] = [];
    for (const attachment of attachments) {
      const content = await this.documents.readDecryptedFile(attachment.storageKey);
      if (createHash('sha256').update(content).digest('hex') !== attachment.sha256) {
        throw new Error(`Attachment ${attachment.id} failed its integrity check`);
      }
      const { storageKey: _omit, ...row } = attachment;
      attachmentRows.push({ ...toPlain(row), content: content.toString('base64') });
    }

    return {
      format: BACKUP_FORMAT,
      version: BACKUP_FORMAT_VERSION,
      createdAt: new Date().toISOString(),
      workspace: {
        id: workspace.id,
        name: workspace.name,
        slug: workspace.slug,
        approvalThreshold: workspace.approvalThreshold?.toString() ?? null,
        backupRetention: workspace.backupRetention,
      },
      data: {
        ...(toPlain({
          accounts,
          contacts,
          journalEntries,
          recurringTemplates,
          budgets,
          animals,
          animalHealthRecords: health,
          animalWeightRecords: weights,
          breedingRecords: breeding,
          landParcels: land,
        }) as unknown as Omit<BackupPayload['data'], 'attachments'>),
        attachments: attachmentRows,
      },
    };
  }

  // --- Read -------------------------------------------------------------------

  async list(workspaceId: string) {
    return this.prisma.backup.findMany({ where: { workspaceId }, select: PUBLIC_FIELDS, orderBy: { startedAt: 'desc' }, take: 100 });
  }

  async status(workspaceId: string) {
    const [workspace, last, lastSuccessful, totals, attachments] = await Promise.all([
      this.prisma.workspace.findUniqueOrThrow({ where: { id: workspaceId }, select: { autoBackupEnabled: true, backupRetention: true } }),
      this.prisma.backup.findFirst({ where: { workspaceId }, select: PUBLIC_FIELDS, orderBy: { startedAt: 'desc' } }),
      this.prisma.backup.findFirst({ where: { workspaceId, status: 'COMPLETED' }, select: PUBLIC_FIELDS, orderBy: { startedAt: 'desc' } }),
      this.prisma.backup.aggregate({ where: { workspaceId, status: 'COMPLETED' }, _count: true, _sum: { sizeBytes: true } }),
      this.prisma.attachment.aggregate({ where: { workspaceId }, _sum: { sizeBytes: true } }),
    ]);
    return {
      autoBackupEnabled: workspace.autoBackupEnabled,
      retention: workspace.backupRetention,
      lastBackup: last,
      lastSuccessfulBackup: lastSuccessful,
      backupCount: totals._count,
      backupBytes: totals._sum.sizeBytes ?? 0,
      documentBytes: attachments._sum.sizeBytes ?? 0,
      provider: { id: this.storage.id, connected: true },
    };
  }

  async updateSettings(workspaceId: string, dto: { autoBackupEnabled?: boolean; retention?: number }) {
    await this.prisma.workspace.update({
      where: { id: workspaceId },
      data: {
        ...(dto.autoBackupEnabled !== undefined ? { autoBackupEnabled: dto.autoBackupEnabled } : {}),
        ...(dto.retention !== undefined ? { backupRetention: dto.retention } : {}),
      },
    });
    await this.pruneScheduled(workspaceId);
    return this.status(workspaceId);
  }

  /** The encrypted file, after checking it still matches its recorded checksum. */
  async download(workspaceId: string, backupId: string) {
    const backup = await this.requireCompleted(workspaceId, backupId);
    const file = await this.readVerifiedFile(backup);
    const day = backup.startedAt.toISOString().slice(0, 10);
    return { file, fileName: `tangent-backup-${day}-${backup.id.slice(0, 8)}.tsmbak` };
  }

  // --- Verify -------------------------------------------------------------------

  /** Full integrity check without changing anything. */
  async verify(workspaceId: string, backupId: string) {
    const backup = await this.requireCompleted(workspaceId, backupId);
    try {
      const { result, payload } = await this.openFile(await this.readVerifiedFile(backup));
      return { valid: result.valid, errors: result.errors, counts: result.counts, createdAt: payload?.createdAt, checksumMatches: true };
    } catch (error) {
      return { valid: false, errors: [(error as Error).message], counts: null, checksumMatches: !(error instanceof ChecksumError) };
    }
  }

  // --- Restore ------------------------------------------------------------------

  async restoreFromBackup(workspaceId: string, backupId: string, userId: string) {
    const backup = await this.requireCompleted(workspaceId, backupId);
    const { result, payload } = await this.openFile(await this.readVerifiedFile(backup));
    if (!result.valid || !payload) {
      throw new BadRequestException({ message: 'This backup failed verification and was not restored', errors: result.errors });
    }
    return this.restore(payload, userId);
  }

  /**
   * Restore from an uploaded .tsmbak file. Only the owner of the workspace
   * the backup came from (or the Super Admin Owner) may restore it, so a
   * leaked file can't be imported by another account on this server.
   */
  async restoreFromFile(file: Buffer | undefined, userId: string, globalRole: string) {
    if (!file || file.length === 0) throw new BadRequestException('Choose a backup file');
    let opened;
    try {
      opened = await this.openFile(file);
    } catch (error) {
      throw new BadRequestException((error as Error).message);
    }
    const { result, payload } = opened;
    if (!result.valid || !payload) {
      throw new BadRequestException({ message: 'This backup failed verification and was not restored', errors: result.errors });
    }
    if (globalRole !== 'SUPER_ADMIN_OWNER') {
      const membership = await this.prisma.workspaceMembership.findUnique({
        where: { userId_workspaceId: { userId, workspaceId: payload.workspace.id } },
      });
      if (!membership || membership.role !== 'OWNER' || !membership.isActive) {
        throw new ForbiddenException('Only the owner of the workspace this backup came from can restore it');
      }
    }
    return this.restore(payload, userId);
  }

  /**
   * Creates a NEW workspace from a verified payload: fresh ids for every row
   * with all references remapped, in one transaction. Nothing existing is
   * modified or deleted. Attachment files are re-encrypted under the new
   * workspace; if anything fails, written files are removed and the
   * transaction rolls back, so no partial restore remains.
   */
  private async restore(payload: BackupPayload, userId: string) {
    const d = payload.data;
    const map = new Map<string, string>();
    const remap = (id: unknown): string | null => {
      if (id === null || id === undefined) return null;
      const mapped = map.get(String(id));
      if (!mapped) throw new Error(`Unmapped reference ${String(id)}`);
      return mapped;
    };
    for (const key of Object.keys(d) as Array<keyof BackupPayload['data']>) {
      for (const row of d[key]) {
        map.set(row.id, randomUUID());
        if (key === 'journalEntries') for (const line of (row as { lines: Array<{ id: string }> }).lines) map.set(line.id, randomUUID());
      }
    }

    const newWorkspaceId = randomUUID();
    const restoredOn = new Date().toISOString().slice(0, 10);
    const slug = await this.uniqueSlug(`${payload.workspace.slug}-restored`);
    const writtenFiles: string[] = [];

    try {
      // Files first (outside the DB transaction), so the transaction only does inserts.
      const attachmentKeys = new Map<string, string>();
      for (const row of d.attachments) {
        const content = Buffer.from(row.content, 'base64');
        if (createHash('sha256').update(content).digest('hex') !== row.sha256) {
          throw new Error(`Attachment ${row.id} content does not match its checksum`);
        }
        const key = await this.documents.storeEncryptedFile(newWorkspaceId, content);
        writtenFiles.push(key);
        attachmentKeys.set(row.id, key);
      }

      await this.prisma.$transaction(
        async (tx) => {
          await tx.workspace.create({
            data: {
              id: newWorkspaceId,
              name: `${payload.workspace.name} (restored ${restoredOn})`,
              slug,
              approvalThreshold: payload.workspace.approvalThreshold,
              backupRetention: payload.workspace.backupRetention,
              users: { create: { userId, role: 'OWNER', acceptedAt: new Date() } },
            },
          });
          const ws = { workspaceId: newWorkspaceId };
          const strip = <T extends Record<string, unknown>>(row: T, ...keys: string[]) => {
            const copy: Record<string, unknown> = { ...row };
            for (const key of ['id', 'workspaceId', ...keys]) delete copy[key];
            return copy;
          };

          await tx.account.createMany({ data: d.accounts.map((r) => ({ ...strip(r), ...ws, id: remap(r.id)! })) as Prisma.AccountCreateManyInput[] });
          await tx.contact.createMany({ data: d.contacts.map((r) => ({ ...strip(r), ...ws, id: remap(r.id)! })) as Prisma.ContactCreateManyInput[] });

          // Animals: insert without pedigree first, then link parents (parents may appear later in the list).
          await tx.animal.createMany({
            data: d.animals.map((r) => ({ ...strip(r, 'sireId', 'damId'), ...ws, id: remap(r.id)! })) as Prisma.AnimalCreateManyInput[],
          });
          for (const r of d.animals.filter((a) => a.sireId || a.damId)) {
            await tx.animal.update({ where: { id: remap(r.id)! }, data: { sireId: remap(r.sireId), damId: remap(r.damId) } });
          }

          await tx.landParcel.createMany({
            data: d.landParcels.map((r) => ({
              ...strip(r),
              ...ws,
              id: remap(r.id)!,
              counterpartyContactId: remap(r.counterpartyContactId),
            })) as Prisma.LandParcelCreateManyInput[],
          });

          // Journal entries are exact historical copies (same amounts, status, dates) in the
          // new workspace. Receipt verification codes are globally unique, so copies get none.
          await tx.journalEntry.createMany({
            data: d.journalEntries.map((r) => ({
              ...strip(r, 'lines', 'reversalOfId', 'verificationCode'),
              ...ws,
              id: remap(r.id)!,
              contactId: remap(r.contactId),
              animalId: remap(r.animalId),
              landParcelId: remap(r.landParcelId),
            })) as Prisma.JournalEntryCreateManyInput[],
          });
          for (const r of d.journalEntries.filter((e) => e.reversalOfId)) {
            await tx.journalEntry.update({ where: { id: remap(r.id)! }, data: { reversalOfId: remap(r.reversalOfId) } });
          }
          await tx.journalLine.createMany({
            data: d.journalEntries.flatMap((entry) =>
              entry.lines.map((line) => ({
                id: remap(line.id)!,
                journalEntryId: remap(entry.id)!,
                accountId: remap(line.accountId)!,
                amount: line.amount as string,
                reconciledAt: (line.reconciledAt as string | null) ?? null,
              })),
            ),
          });

          await tx.recurringTemplate.createMany({
            data: d.recurringTemplates.map((r) => ({
              ...strip(r),
              ...ws,
              id: remap(r.id)!,
              fromAccountId: remap(r.fromAccountId)!,
              toAccountId: remap(r.toAccountId)!,
              contactId: remap(r.contactId),
            })) as Prisma.RecurringTemplateCreateManyInput[],
          });
          await tx.budget.createMany({
            data: d.budgets.map((r) => ({ ...strip(r), ...ws, id: remap(r.id)!, accountId: remap(r.accountId)! })) as Prisma.BudgetCreateManyInput[],
          });
          await tx.animalHealthRecord.createMany({
            data: d.animalHealthRecords.map((r) => ({ ...strip(r), ...ws, id: remap(r.id)!, animalId: remap(r.animalId)! })) as Prisma.AnimalHealthRecordCreateManyInput[],
          });
          await tx.animalWeightRecord.createMany({
            data: d.animalWeightRecords.map((r) => ({ ...strip(r), ...ws, id: remap(r.id)!, animalId: remap(r.animalId)! })) as Prisma.AnimalWeightRecordCreateManyInput[],
          });
          await tx.breedingRecord.createMany({
            data: d.breedingRecords.map((r) => ({
              ...strip(r),
              ...ws,
              id: remap(r.id)!,
              damId: remap(r.damId)!,
              sireId: remap(r.sireId),
            })) as Prisma.BreedingRecordCreateManyInput[],
          });
          await tx.attachment.createMany({
            data: d.attachments.map((r) => ({
              ...strip(r, 'content'),
              ...ws,
              id: remap(r.id)!,
              recordId: r.module === 'GENERAL' ? null : remap(r.recordId),
              storageKey: attachmentKeys.get(r.id)!,
            })) as Prisma.AttachmentCreateManyInput[],
          });
        },
        { timeout: RESTORE_TRANSACTION_TIMEOUT_MS, maxWait: 30_000 },
      );
    } catch (error) {
      for (const key of writtenFiles) await this.documents.removeStoredFile(key).catch(() => undefined);
      this.logger.error(`Restore failed: ${(error as Error).message}`);
      throw new InternalServerErrorException('The restore failed and nothing was changed');
    }

    const workspace = await this.prisma.workspace.findUniqueOrThrow({ where: { id: newWorkspaceId } });
    await this.notifications.notifyUsers([userId], {
      workspaceId: newWorkspaceId,
      category: 'BACKUP',
      severity: 'INFO',
      title: 'Backup restored',
      body: `"${workspace.name}" was created from the backup of ${payload.createdAt.slice(0, 10)}. Your original workspace was not changed.`,
      link: '/dashboard',
    });
    return { workspace: { ...workspace, myRole: 'OWNER' }, counts: validateBackupPayload(payload).counts };
  }

  // --- Delete / prune ------------------------------------------------------------

  async remove(workspaceId: string, backupId: string) {
    const backup = await this.prisma.backup.findFirst({ where: { id: backupId, workspaceId } });
    if (!backup) throw new NotFoundException('Backup not found');
    if (backup.status === 'RUNNING') throw new BadRequestException('This backup is still running');
    await this.prisma.backup.delete({ where: { id: backup.id } });
    if (backup.storageKey) await this.storage.remove(backup.storageKey);
    return { deleted: true };
  }

  /** Keeps the newest `backupRetention` scheduled backups; manual backups are never pruned automatically. */
  async pruneScheduled(workspaceId: string): Promise<number> {
    const workspace = await this.prisma.workspace.findUniqueOrThrow({ where: { id: workspaceId }, select: { backupRetention: true } });
    const old = await this.prisma.backup.findMany({
      where: { workspaceId, trigger: 'SCHEDULED', status: { in: ['COMPLETED', 'FAILED'] } },
      orderBy: { startedAt: 'desc' },
      skip: workspace.backupRetention,
    });
    for (const backup of old) {
      await this.prisma.backup.delete({ where: { id: backup.id } });
      if (backup.storageKey) await this.storage.remove(backup.storageKey).catch(() => undefined);
    }
    return old.length;
  }

  /** Daily job: one scheduled backup per active workspace with auto-backup on, then prune. */
  async runScheduledBackups(): Promise<{ completed: number; failed: number }> {
    const workspaces = await this.prisma.workspace.findMany({ where: { isActive: true, autoBackupEnabled: true }, select: { id: true } });
    const result = { completed: 0, failed: 0 };
    for (const { id } of workspaces) {
      try {
        await this.createBackup(id, 'SCHEDULED');
        await this.pruneScheduled(id);
        result.completed++;
      } catch {
        result.failed++; // already recorded on the Backup row and notified
      }
    }
    return result;
  }

  // --- Helpers ---------------------------------------------------------------------

  private async requireCompleted(workspaceId: string, backupId: string) {
    const backup = await this.prisma.backup.findFirst({ where: { id: backupId, workspaceId } });
    if (!backup) throw new NotFoundException('Backup not found');
    if (backup.status !== 'COMPLETED' || !backup.storageKey) throw new BadRequestException('This backup did not complete');
    return backup;
  }

  private async readVerifiedFile(backup: { storageKey: string | null; sha256: string | null }) {
    let file: Buffer;
    try {
      file = await this.storage.get(backup.storageKey!);
    } catch {
      throw new ChecksumError('The backup file is missing from storage');
    }
    if (createHash('sha256').update(file).digest('hex') !== backup.sha256) {
      throw new ChecksumError('The backup file does not match its recorded checksum');
    }
    return file;
  }

  /** Decrypt + gunzip + parse + validate. */
  private async openFile(file: Buffer): Promise<{ result: ValidationResult; payload: BackupPayload | null }> {
    let json: unknown;
    try {
      json = JSON.parse((await gunzipAsync(decryptBackup(file, this.key))).toString('utf8'));
    } catch (error) {
      if (error instanceof BackupFileError) throw error;
      throw new BackupFileError('The backup file could not be read');
    }
    const result = validateBackupPayload(json);
    return { result, payload: result.valid ? (json as BackupPayload) : null };
  }

  private async uniqueSlug(base: string): Promise<string> {
    for (let i = 0; i < 10; i++) {
      const candidate = `${base}-${randomBytes(3).toString('hex')}`;
      if (!(await this.prisma.workspace.findUnique({ where: { slug: candidate } }))) return candidate;
    }
    throw new InternalServerErrorException('Could not create a unique workspace identifier');
  }
}

class ChecksumError extends Error {}
