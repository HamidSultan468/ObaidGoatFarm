import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, resolve, sep } from 'node:path';

/**
 * Where encrypted backup files live. Files are already encrypted before a
 * provider ever sees them, so a provider never needs to be trusted with
 * plaintext. Cloud adapters (Google Drive, OneDrive, Dropbox, S3) implement
 * this same interface once their OAuth apps/credentials exist.
 */
export interface BackupStorageProvider {
  readonly id: string;
  put(key: string, content: Buffer): Promise<void>;
  get(key: string): Promise<Buffer>;
  remove(key: string): Promise<void>;
}

export const BACKUP_STORAGE_PROVIDER = Symbol('BACKUP_STORAGE_PROVIDER');

/** Local disk under STORAGE_DIR/backups. */
@Injectable()
export class LocalDiskBackupProvider implements BackupStorageProvider {
  readonly id = 'LOCAL';
  private readonly root: string;

  constructor(config: ConfigService) {
    const dir = config.get<string>('storageDir') ?? 'storage';
    this.root = join(isAbsolute(dir) ? dir : resolve(process.cwd(), dir), 'backups');
  }

  async put(key: string, content: Buffer): Promise<void> {
    const path = this.resolveKey(key);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, content, { flag: 'wx' });
  }

  async get(key: string): Promise<Buffer> {
    return readFile(this.resolveKey(key));
  }

  async remove(key: string): Promise<void> {
    await rm(this.resolveKey(key), { force: true });
  }

  private resolveKey(key: string): string {
    const path = resolve(join(this.root, key));
    if (!path.startsWith(this.root + sep)) {
      throw new Error('Invalid backup storage key');
    }
    return path;
  }
}
