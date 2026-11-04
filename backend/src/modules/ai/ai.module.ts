import { Module } from '@nestjs/common';
import { AccountingModule } from '../accounting/accounting.module.js';
import { DocumentsModule } from '../documents/documents.module.js';
import { DraftsService } from '../drafts/drafts.service.js';
import { FarmModule } from '../farm/farm.module.js';
import { NotificationsModule } from '../notifications/notifications.module.js';
import { AiProvidersController, DraftsController } from './ai.controller.js';
import { AiService } from './ai.service.js';

/** AI integration (Phase 11): encrypted provider keys, failover, usage, and human-approved drafts. */
@Module({
  imports: [AccountingModule, FarmModule, DocumentsModule, NotificationsModule],
  controllers: [AiProvidersController, DraftsController],
  providers: [AiService, DraftsService],
  // WhatsApp turns messages into drafts through AiService.
  exports: [AiService, DraftsService],
})
export class AiModule {}
