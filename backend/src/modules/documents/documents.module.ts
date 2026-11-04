import { Module } from '@nestjs/common';
import { DocumentsController } from './documents.controller.js';
import { DocumentsService } from './documents.service.js';

/** Documents & Records (Phase 08): encrypted, access-controlled file attachments. */
@Module({
  controllers: [DocumentsController],
  providers: [DocumentsService],
  // Backup reads and re-stores attachment files through DocumentsService.
  exports: [DocumentsService],
})
export class DocumentsModule {}
