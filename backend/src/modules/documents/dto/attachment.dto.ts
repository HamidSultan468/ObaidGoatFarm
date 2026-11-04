import { AttachmentModule } from '@prisma/client';
import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/** Multipart form fields sent alongside the `file` part. */
export class UploadAttachmentDto {
  @IsEnum(AttachmentModule)
  module!: AttachmentModule;

  /** Required for every module except GENERAL. */
  @IsOptional()
  @IsString()
  recordId?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(150)
  title?: string;
}

export class ListAttachmentsQueryDto {
  @IsOptional()
  @IsEnum(AttachmentModule)
  module?: AttachmentModule;

  @IsOptional()
  @IsString()
  recordId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}
