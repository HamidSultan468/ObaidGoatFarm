import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import {
  IsBoolean,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
} from 'class-validator';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../common/decorators/current-user.decorator.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../common/guards/workspace.guard.js';
import { RECORD_WRITERS } from '../../common/roles/record-roles.js';
import { DraftsService } from '../drafts/drafts.service.js';
import { AiService } from './ai.service.js';

const MODEL_PATTERN = /^claude-[a-z0-9-]{3,60}$/;

export class AddProviderDto {
  @IsString()
  @MinLength(20)
  @MaxLength(300)
  apiKey!: string;

  @IsString()
  @Matches(MODEL_PATTERN, { message: 'model must be a Claude model id, e.g. claude-opus-5-5' })
  model!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  priority?: number;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  monthlyRequestLimit?: number | null;
}

export class UpdateProviderDto {
  @IsOptional()
  @IsString()
  @MinLength(20)
  @MaxLength(300)
  apiKey?: string;

  @IsOptional()
  @IsString()
  @Matches(MODEL_PATTERN, { message: 'model must be a Claude model id, e.g. claude-opus-5-5' })
  model?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  priority?: number;

  @IsOptional()
  @IsBoolean()
  isEnabled?: boolean;

  @IsOptional()
  @ValidateIf((_, v) => v !== null)
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  monthlyRequestLimit?: number | null;
}

export class DraftFromTextDto {
  @IsString()
  @MinLength(2)
  @MaxLength(1000)
  text!: string;
}

export class DraftFromReceiptDto {
  @IsString()
  attachmentId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class ApproveDraftDto {
  /** The reviewer's corrected field values; omit to approve as proposed. */
  @IsOptional()
  @IsObject()
  payload?: Record<string, unknown>;
}

export class RejectDraftDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

/** AI provider settings and usage: OWNER/ADMIN only. Keys are write-only. */
@Controller('workspaces/:workspaceId/ai/providers')
@UseGuards(WorkspaceGuard, RolesGuard)
@Roles('OWNER', 'ADMIN')
export class AiProvidersController {
  constructor(private readonly ai: AiService) {}

  @Get()
  list(@Param('workspaceId') workspaceId: string) {
    return this.ai.listProviders(workspaceId);
  }

  @Post()
  @AuditAction('ai.provider.add')
  add(@Param('workspaceId') workspaceId: string, @Body() dto: AddProviderDto) {
    return this.ai.addProvider(workspaceId, dto);
  }

  @Get('usage')
  usage(@Param('workspaceId') workspaceId: string) {
    return this.ai.usage(workspaceId);
  }

  @Patch(':configId')
  @AuditAction('ai.provider.update')
  update(@Param('workspaceId') workspaceId: string, @Param('configId') configId: string, @Body() dto: UpdateProviderDto) {
    return this.ai.updateProvider(workspaceId, configId, dto);
  }

  @Delete(':configId')
  @AuditAction('ai.provider.remove')
  remove(@Param('workspaceId') workspaceId: string, @Param('configId') configId: string) {
    return this.ai.removeProvider(workspaceId, configId);
  }

  @Post(':configId/test')
  @AuditAction('ai.provider.test')
  test(@Param('workspaceId') workspaceId: string, @Param('configId') configId: string) {
    return this.ai.testProvider(workspaceId, configId);
  }
}

/** Drafts: create with AI, list, review. Any record writer; approval re-validates everything. */
@Controller('workspaces/:workspaceId/drafts')
@UseGuards(WorkspaceGuard, RolesGuard)
@Roles(...RECORD_WRITERS)
export class DraftsController {
  constructor(
    private readonly ai: AiService,
    private readonly drafts: DraftsService,
  ) {}

  @Post('from-text')
  @AuditAction('ai.draft.fromText')
  fromText(@Param('workspaceId') workspaceId: string, @CurrentUser() user: AuthenticatedUser, @Body() dto: DraftFromTextDto) {
    return this.ai.draftFromText(workspaceId, user.userId, dto.text);
  }

  @Post('from-receipt')
  @AuditAction('ai.draft.fromReceipt')
  fromReceipt(@Param('workspaceId') workspaceId: string, @CurrentUser() user: AuthenticatedUser, @Body() dto: DraftFromReceiptDto) {
    return this.ai.draftFromReceipt(workspaceId, user.userId, dto.attachmentId, dto.note);
  }

  @Get()
  list(@Param('workspaceId') workspaceId: string, @Query('status') status?: string) {
    return this.drafts.list(workspaceId, status && ['PENDING', 'APPROVED', 'REJECTED'].includes(status) ? status : undefined);
  }

  @Get(':draftId')
  get(@Param('workspaceId') workspaceId: string, @Param('draftId') draftId: string) {
    return this.drafts.get(workspaceId, draftId);
  }

  @Post(':draftId/approve')
  @AuditAction('draft.approve')
  approve(@Param('workspaceId') workspaceId: string, @Param('draftId') draftId: string, @CurrentUser() user: AuthenticatedUser, @Body() dto: ApproveDraftDto) {
    return this.drafts.approve(workspaceId, draftId, user.userId, dto.payload);
  }

  @Post(':draftId/reject')
  @AuditAction('draft.reject')
  reject(@Param('workspaceId') workspaceId: string, @Param('draftId') draftId: string, @CurrentUser() user: AuthenticatedUser, @Body() dto: RejectDraftDto) {
    return this.drafts.reject(workspaceId, draftId, user.userId, dto.reason);
  }
}

