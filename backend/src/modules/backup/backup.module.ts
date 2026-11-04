import { Injectable, Logger, Module } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { DocumentsModule } from '../documents/documents.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { AdminBackupController, BackupController, BackupRestoreController } from './backup.controller.js';
import { BackupService } from './backup.service.js';
import { BACKUP_STORAGE_PROVIDER, LocalDiskBackupProvider } from './storage/backup-storage.provider.js';

/** Daily automatic backups at 02:00 server time. */
@Injectable()
export class BackupScheduler {
  private readonly logger = new Logger(BackupScheduler.name);
  private running = false;

  constructor(private readonly backups: BackupService) {}

  @Cron('0 2 * * *')
  async runDaily() {
    if (this.running) return;
    this.running = true;
    try {
      const result = await this.backups.runScheduledBackups();
      this.logger.log(`Daily backups: ${result.completed} completed, ${result.failed} failed`);
    } finally {
      this.running = false;
    }
  }
}

/** Backup & Restore (Phase 10). Swap the storage provider here to use a cloud adapter. */
@Module({
  imports: [DocumentsModule, NotificationsModule],
  controllers: [BackupController, BackupRestoreController, AdminBackupController],
  providers: [BackupService, BackupScheduler, { provide: BACKUP_STORAGE_PROVIDER, useClass: LocalDiskBackupProvider }],
})
export class BackupModule {}
