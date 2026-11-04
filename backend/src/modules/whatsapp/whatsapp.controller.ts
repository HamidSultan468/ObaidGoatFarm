import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Headers,
  HttpCode,
  Logger,
  Param,
  Post,
  Put,
  Query,
  Req,
  Res,
  UnauthorizedException,
  UseGuards,
  type RawBodyRequest,
} from '@nestjs/common';
import { IsBoolean, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import type { Request, Response } from 'express';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../common/decorators/current-user.decorator.js';
import { Public } from '../../common/decorators/public.decorator.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../common/guards/workspace.guard.js';
import { RECORD_WRITERS } from '../../common/roles/record-roles.js';
import { WhatsAppService } from './whatsapp.service.js';

export class SaveWhatsAppConfigDto {
  @IsString()
  @Matches(/^\d{5,30}$/, { message: 'phoneNumberId is the numeric id from Meta (WhatsApp → API Setup)' })
  phoneNumberId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  displayPhone?: string;

  @IsString()
  @MinLength(20)
  @MaxLength(1000)
  accessToken!: string;

  @IsString()
  @MinLength(16)
  @MaxLength(200)
  appSecret!: string;

  @IsOptional()
  @IsBoolean()
  isEnabled?: boolean;
}

export class StartLinkDto {
  @IsString()
  @MaxLength(25)
  phone!: string;
}

/** Workspace WhatsApp settings: OWNER/ADMIN. */
@Controller('workspaces/:workspaceId/whatsapp')
@UseGuards(WorkspaceGuard, RolesGuard)
@Roles('OWNER', 'ADMIN')
export class WhatsAppSettingsController {
  constructor(private readonly whatsapp: WhatsAppService) {}

  @Get('config')
  getConfig(@Param('workspaceId') workspaceId: string) {
    return this.whatsapp.getConfig(workspaceId);
  }

  @Put('config')
  @AuditAction('whatsapp.config.save')
  saveConfig(@Param('workspaceId') workspaceId: string, @Body() dto: SaveWhatsAppConfigDto) {
    return this.whatsapp.saveConfig(workspaceId, dto);
  }

  @Delete('config')
  @AuditAction('whatsapp.config.remove')
  removeConfig(@Param('workspaceId') workspaceId: string) {
    return this.whatsapp.removeConfig(workspaceId);
  }

  @Get('links')
  listLinks(@Param('workspaceId') workspaceId: string) {
    return this.whatsapp.listLinks(workspaceId);
  }

  @Delete('links/:linkId')
  @AuditAction('whatsapp.link.remove')
  removeLink(@Param('workspaceId') workspaceId: string, @Param('linkId') linkId: string) {
    return this.whatsapp.removeLink(workspaceId, linkId);
  }

  @Get('messages')
  messages(@Param('workspaceId') workspaceId: string) {
    return this.whatsapp.listMessages(workspaceId);
  }
}

/** A member linking their own phone (anyone who may create records). */
@Controller('workspaces/:workspaceId/whatsapp/my-link')
@UseGuards(WorkspaceGuard, RolesGuard)
@Roles(...RECORD_WRITERS)
export class WhatsAppLinkController {
  constructor(private readonly whatsapp: WhatsAppService) {}

  @Get()
  get(@Param('workspaceId') workspaceId: string, @CurrentUser() user: AuthenticatedUser) {
    return this.whatsapp.myLink(workspaceId, user.userId);
  }

  @Post()
  @AuditAction('whatsapp.link.start')
  start(@Param('workspaceId') workspaceId: string, @CurrentUser() user: AuthenticatedUser, @Body() dto: StartLinkDto) {
    return this.whatsapp.startLink(workspaceId, user.userId, dto.phone);
  }

  @Delete()
  @AuditAction('whatsapp.link.unlink')
  unlink(@Param('workspaceId') workspaceId: string, @CurrentUser() user: AuthenticatedUser) {
    return this.whatsapp.unlink(workspaceId, user.userId);
  }
}

/**
 * Meta's webhook. Public (no JWT): authenticity comes from the
 * X-Hub-Signature-256 HMAC, checked against the target workspace's app
 * secret before anything is processed. Replies 200 at once and processes
 * afterwards, as Meta expects a fast acknowledgement.
 */
@Controller('whatsapp/webhook')
@Public()
export class WhatsAppWebhookController {
  private readonly logger = new Logger(WhatsAppWebhookController.name);

  constructor(private readonly whatsapp: WhatsAppService) {}

  @Get()
  async verify(
    @Query('hub.mode') mode: string | undefined,
    @Query('hub.verify_token') token: string | undefined,
    @Query('hub.challenge') challenge: string | undefined,
    @Res() res: Response,
  ) {
    const result = await this.whatsapp.verifyWebhook(mode, token, challenge);
    if (result === null) throw new ForbiddenException('Verification failed');
    res.status(200).type('text/plain').send(result);
  }

  @Post()
  @HttpCode(200)
  async receive(@Req() req: RawBodyRequest<Request>, @Headers('x-hub-signature-256') signature?: string) {
    const work = await this.whatsapp.acceptWebhook(req.rawBody, signature);
    if (!work) throw new UnauthorizedException('Invalid signature');
    void work().catch((error: Error) => this.logger.error(`Webhook processing failed: ${error.message}`));
    return { received: true };
  }
}
