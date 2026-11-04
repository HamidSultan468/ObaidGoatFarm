import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../common/decorators/current-user.decorator.js';
import { GlobalRoles } from '../../common/decorators/global-roles.decorator.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { GlobalRolesGuard } from '../../common/guards/global-roles.guard.js';
import { MfaRequiredGuard } from '../../common/guards/mfa-required.guard.js';
import { RolesGuard } from '../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../common/guards/workspace.guard.js';
import { BackupService } from './backup.service.js';

/** Upload limit for restoring from a file. */
const MAX_RESTORE_FILE_BYTES = 200 * 1024 * 1024;

export class UpdateBackupSettingsDto {
  @IsOptional()
  @IsBoolean()
  autoBackupEnabled?: boolean;

  /** How many automatic (daily) backups to keep. */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(90)
  retention?: number;
}

/** Workspace backups: OWNER/ADMIN manage; restore is OWNER only. */
@Controller('workspaces/:workspaceId/backups')
@UseGuards(WorkspaceGuard, RolesGuard)
@Roles('OWNER', 'ADMIN')
export class BackupController {
  constructor(private readonly backups: BackupService) {}

  @Get()
  list(@Param('workspaceId') workspaceId: string) {
    return this.backups.list(workspaceId);
  }

  @Get('status')
  status(@Param('workspaceId') workspaceId: string) {
    return this.backups.status(workspaceId);
  }

  @Post()
  @AuditAction('backup.create')
  create(@Param('workspaceId') workspaceId: string, @CurrentUser() user: AuthenticatedUser) {
    return this.backups.createBackup(workspaceId, 'MANUAL', user.userId);
  }

  @Patch('settings')
  @AuditAction('backup.settings.update')
  updateSettings(@Param('workspaceId') workspaceId: string, @Body() dto: UpdateBackupSettingsDto) {
    return this.backups.updateSettings(workspaceId, dto);
  }

  @Post(':backupId/verify')
  @AuditAction('backup.verify')
  verify(@Param('workspaceId') workspaceId: string, @Param('backupId') backupId: string) {
    return this.backups.verify(workspaceId, backupId);
  }

  @Get(':backupId/download')
  @AuditAction('backup.download')
  async download(@Param('workspaceId') workspaceId: string, @Param('backupId') backupId: string, @Res() res: Response) {
    const { file, fileName } = await this.backups.download(workspaceId, backupId);
    res.set({
      'Content-Type': 'application/octet-stream',
      'Content-Length': String(file.length),
      'Content-Disposition': `attachment; filename="${fileName}"`,
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(file);
  }

  /** Verifies, then restores into a brand-new workspace. The current workspace is never changed. */
  @Post(':backupId/restore')
  @Roles('OWNER')
  @AuditAction('backup.restore')
  restore(@Param('workspaceId') workspaceId: string, @Param('backupId') backupId: string, @CurrentUser() user: AuthenticatedUser) {
    return this.backups.restoreFromBackup(workspaceId, backupId, user.userId);
  }

  @Delete(':backupId')
  @Roles('OWNER')
  @AuditAction('backup.delete')
  remove(@Param('workspaceId') workspaceId: string, @Param('backupId') backupId: string) {
    return this.backups.remove(workspaceId, backupId);
  }
}

/** Super Admin Owner: run the daily scheduled backups now (operations / recovery drills). */
@Controller('admin/backups')
@UseGuards(GlobalRolesGuard, MfaRequiredGuard)
@GlobalRoles('SUPER_ADMIN_OWNER')
export class AdminBackupController {
  constructor(private readonly backups: BackupService) {}

  @Post('run-scheduled')
  @AuditAction('admin.backup.runScheduled')
  runScheduled() {
    return this.backups.runScheduledBackups();
  }
}

/** Restore from an uploaded .tsmbak (owner of the source workspace or Super Admin Owner only). */
@Controller('backups')
export class BackupRestoreController {
  constructor(private readonly backups: BackupService) {}

  @Post('restore-file')
  @AuditAction('backup.restoreFile')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_RESTORE_FILE_BYTES, files: 1 } }))
  restoreFile(@CurrentUser() user: AuthenticatedUser, @UploadedFile() file?: { buffer: Buffer }) {
    return this.backups.restoreFromFile(file?.buffer, user.userId, user.globalRole);
  }
}
