import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
  PayloadTooLargeException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AttachmentModule } from '@prisma/client';
import { createHash, randomUUID } from 'node:crypto';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, resolve, sep } from 'node:path';
import { EncryptionService } from '../../common/crypto/encryption.service.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { ListAttachmentsQueryDto, UploadAttachmentDto } from './dto/attachment.dto.js';
import { MAX_UPLOAD_BYTES, sanitizeFileName, sniffMimeType } from './file-type.util.js';

/** The subset of a multer file this module relies on (memory storage). */
export interface UploadedFileData {
  originalname: string;
  size: number;
  buffer: Buffer;
}

/** Metadata safe to return to clients: never the storage key. */
const PUBLIC_FIELDS = {
  id: true,
  module: true,
  recordId: true,
  title: true,
  fileName: true,
  mimeType: true,
  sizeBytes: true,
  sha256: true,
  uploadedByUserId: true,
  createdAt: true,
} as const;

@Injectable()
export class DocumentsService {
  private readonly logger = new Logger(DocumentsService.name);
  private readonly storageRoot: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly encryption: EncryptionService,
    config: ConfigService,
  ) {
    const dir = config.get<string>('storageDir') ?? 'storage';
    this.storageRoot = isAbsolute(dir) ? dir : resolve(process.cwd(), dir);
  }

  async upload(workspaceId: string, userId: string, dto: UploadAttachmentDto, file?: UploadedFileData) {
    if (!file || file.size === 0) {
      throw new BadRequestException('A non-empty file is required');
    }
    if (file.size > MAX_UPLOAD_BYTES) {
      throw new PayloadTooLargeException('Files may be at most 10 MB');
    }
    const mimeType = sniffMimeType(file.buffer);
    if (!mimeType) {
      throw new BadRequestException('Only JPEG, PNG, WEBP images and PDF documents are allowed');
    }
    await this.assertRecordInWorkspace(workspaceId, dto.module, dto.recordId);

    const fileName = sanitizeFileName(file.originalname);
    const storageKey = await this.storeEncryptedFile(workspaceId, file.buffer);

    try {
      return await this.prisma.attachment.create({
        data: {
          workspaceId,
          module: dto.module,
          recordId: dto.module === 'GENERAL' ? null : dto.recordId,
          title: dto.title?.trim() || fileName,
          fileName,
          mimeType,
          sizeBytes: file.size,
          sha256: createHash('sha256').update(file.buffer).digest('hex'),
          storageKey,
          uploadedByUserId: userId,
        },
        select: PUBLIC_FIELDS,
      });
    } catch (error) {
      // Never leave an orphaned encrypted file behind if the row failed.
      await this.removeStoredFile(storageKey);
      throw error;
    }
  }

  /** Encrypts and writes file bytes for a workspace; returns the new storage key. Used by upload and backup restore. */
  async storeEncryptedFile(workspaceId: string, content: Buffer): Promise<string> {
    const storageKey = `${workspaceId}/${randomUUID()}.bin`;
    const absolutePath = this.resolveKey(storageKey);
    await mkdir(dirname(absolutePath), { recursive: true });
    await writeFile(absolutePath, this.encryption.encryptBuffer(content), { flag: 'wx' });
    return storageKey;
  }

  /** Decrypted bytes of a stored file (GCM auth tag verified). Used by download and backup. */
  async readDecryptedFile(storageKey: string): Promise<Buffer> {
    return this.encryption.decryptBuffer(await readFile(this.resolveKey(storageKey)));
  }

  async removeStoredFile(storageKey: string): Promise<void> {
    await rm(this.resolveKey(storageKey), { force: true });
  }

  async findAll(workspaceId: string, query: ListAttachmentsQueryDto) {
    const search = query.search?.trim();
    return this.prisma.attachment.findMany({
      where: {
        workspaceId,
        ...(query.module ? { module: query.module } : {}),
        ...(query.recordId ? { recordId: query.recordId } : {}),
        ...(search
          ? { OR: [{ title: { contains: search, mode: 'insensitive' } }, { fileName: { contains: search, mode: 'insensitive' } }] }
          : {}),
      },
      select: PUBLIC_FIELDS,
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  /** Decrypts and integrity-checks the file; the caller streams it to the client. */
  async download(workspaceId: string, attachmentId: string) {
    const attachment = await this.prisma.attachment.findFirst({ where: { id: attachmentId, workspaceId } });
    if (!attachment) {
      throw new NotFoundException('Document not found');
    }
    let content: Buffer;
    try {
      content = await this.readDecryptedFile(attachment.storageKey);
    } catch (error) {
      this.logger.error(`Could not read/decrypt attachment ${attachment.id}: ${(error as Error).message}`);
      throw new InternalServerErrorException('This document could not be read');
    }
    if (createHash('sha256').update(content).digest('hex') !== attachment.sha256) {
      this.logger.error(`Integrity check failed for attachment ${attachment.id}`);
      throw new InternalServerErrorException('This document failed its integrity check');
    }
    return { content, fileName: attachment.fileName, mimeType: attachment.mimeType };
  }

  async remove(workspaceId: string, attachmentId: string) {
    const attachment = await this.prisma.attachment.findFirst({ where: { id: attachmentId, workspaceId } });
    if (!attachment) {
      throw new NotFoundException('Document not found');
    }
    await this.prisma.attachment.delete({ where: { id: attachment.id } });
    await this.removeStoredFile(attachment.storageKey);
    return { deleted: true };
  }

  /** Keys are server-generated, but guard anyway: a key must never resolve outside the storage root. */
  private resolveKey(storageKey: string): string {
    const absolutePath = resolve(join(this.storageRoot, storageKey));
    if (!absolutePath.startsWith(this.storageRoot + sep)) {
      throw new InternalServerErrorException('Invalid storage key');
    }
    return absolutePath;
  }

  /** The owning record must exist in this workspace (tenant isolation for attachments). */
  private async assertRecordInWorkspace(workspaceId: string, module: AttachmentModule, recordId?: string) {
    if (module === 'GENERAL') {
      if (recordId) throw new BadRequestException('GENERAL documents do not belong to a record');
      return;
    }
    if (!recordId) {
      throw new BadRequestException(`recordId is required for ${module} documents`);
    }
    const where = { id: recordId, workspaceId };
    const counts: Record<Exclude<AttachmentModule, 'GENERAL'>, () => Promise<number>> = {
      ANIMAL: () => this.prisma.animal.count({ where }),
      LAND: () => this.prisma.landParcel.count({ where }),
      TRANSACTION: () => this.prisma.journalEntry.count({ where }),
      CONTACT: () => this.prisma.contact.count({ where }),
    };
    if ((await counts[module]()) !== 1) {
      throw new BadRequestException('Invalid record for this document');
    }
  }
}
