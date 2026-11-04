import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../common/decorators/current-user.decorator.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../common/guards/workspace.guard.js';
import { RECORD_MANAGERS, RECORD_WRITERS } from '../../common/roles/record-roles.js';
import { DocumentsService, type UploadedFileData } from './documents.service.js';
import { ListAttachmentsQueryDto, UploadAttachmentDto } from './dto/attachment.dto.js';
import { MAX_UPLOAD_BYTES, contentDisposition } from './file-type.util.js';

@Controller('workspaces/:workspaceId/attachments')
@UseGuards(WorkspaceGuard)
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  /** multipart/form-data: `file` + `module`, optional `recordId`, `title`. */
  @Post()
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('documents.attachment.upload')
  // +1 byte so an over-limit file is caught by our check with a clear 413 message.
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES + 1, files: 1 } }))
  upload(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: UploadAttachmentDto,
    @UploadedFile() file?: UploadedFileData,
  ) {
    return this.documentsService.upload(workspaceId, user.userId, dto, file);
  }

  @Get()
  findAll(@Param('workspaceId') workspaceId: string, @Query() query: ListAttachmentsQueryDto) {
    return this.documentsService.findAll(workspaceId, query);
  }

  /** `?inline=true` lets images/PDFs open in the browser instead of downloading. */
  @Get(':attachmentId/download')
  async download(
    @Param('workspaceId') workspaceId: string,
    @Param('attachmentId') attachmentId: string,
    @Query('inline') inline: string | undefined,
    @Res() res: Response,
  ) {
    const file = await this.documentsService.download(workspaceId, attachmentId);
    res.set({
      'Content-Type': file.mimeType,
      'Content-Length': String(file.content.length),
      'Content-Disposition': contentDisposition(file.fileName, inline === 'true'),
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(file.content);
  }

  @Delete(':attachmentId')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_MANAGERS)
  @AuditAction('documents.attachment.delete')
  remove(@Param('workspaceId') workspaceId: string, @Param('attachmentId') attachmentId: string) {
    return this.documentsService.remove(workspaceId, attachmentId);
  }
}
