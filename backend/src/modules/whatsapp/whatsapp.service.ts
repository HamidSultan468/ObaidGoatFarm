import { BadRequestException, ConflictException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, type WhatsAppConfig } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { EncryptionService } from '../../common/crypto/encryption.service.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { AiService } from '../ai/ai.service.js';
import { HELP_TEXT, hashLinkCode, isValidSignature, newLinkCode, normalizePhone, parseCommand } from './whatsapp.util.js';

const LINK_CODE_TTL_MS = 15 * 60_000;
const MAX_LINK_ATTEMPTS = 5;
const GRAPH_TIMEOUT_MS = 15_000;

/** The parts of Meta's webhook payload this module reads. */
interface WebhookPayload {
  object?: string;
  entry?: Array<{
    changes?: Array<{
      value?: {
        metadata?: { phone_number_id?: string };
        messages?: Array<{ id: string; from: string; type: string; text?: { body?: string } }>;
      };
    }>;
  }>;
}

@Injectable()
export class WhatsAppService {
  private readonly logger = new Logger(WhatsAppService.name);
  private readonly graphBase: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly encryption: EncryptionService,
    private readonly ai: AiService,
    config: ConfigService,
  ) {
    this.graphBase = `https://graph.facebook.com/${config.get<string>('whatsappGraphVersion') ?? 'v21.0'}`;
  }

  // --- Configuration (OWNER/ADMIN) ------------------------------------------

  async getConfig(workspaceId: string) {
    const config = await this.prisma.whatsAppConfig.findUnique({ where: { workspaceId } });
    if (!config) return { configured: false };
    return {
      configured: true,
      phoneNumberId: config.phoneNumberId,
      displayPhone: config.displayPhone,
      verifyToken: config.verifyToken,
      isEnabled: config.isEnabled,
      webhookPath: '/whatsapp/webhook',
    };
  }

  async saveConfig(workspaceId: string, dto: { phoneNumberId: string; displayPhone?: string; accessToken: string; appSecret: string; isEnabled?: boolean }) {
    const data = {
      phoneNumberId: dto.phoneNumberId,
      displayPhone: dto.displayPhone,
      accessTokenEncrypted: this.encryption.encrypt(dto.accessToken),
      appSecretEncrypted: this.encryption.encrypt(dto.appSecret),
      isEnabled: dto.isEnabled ?? true,
    };
    try {
      await this.prisma.whatsAppConfig.upsert({
        where: { workspaceId },
        create: { workspaceId, verifyToken: randomBytes(24).toString('hex'), ...data },
        update: data,
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('This WhatsApp number is already connected to another workspace');
      }
      throw error;
    }
    return this.getConfig(workspaceId);
  }

  async removeConfig(workspaceId: string) {
    await this.prisma.whatsAppConfig.deleteMany({ where: { workspaceId } });
    return { deleted: true };
  }

  // --- Linking a member's phone ------------------------------------------------

  /** Starts (or restarts) linking for the signed-in user; returns the one-time code to send from WhatsApp. */
  async startLink(workspaceId: string, userId: string, rawPhone: string) {
    const config = await this.prisma.whatsAppConfig.findUnique({ where: { workspaceId } });
    if (!config || !config.isEnabled) throw new BadRequestException('WhatsApp is not connected for this workspace yet');
    const phoneE164 = normalizePhone(rawPhone);
    if (!phoneE164) throw new BadRequestException('Enter a valid phone number, e.g. +92 300 1234567');

    const taken = await this.prisma.whatsAppLink.findUnique({ where: { workspaceId_phoneE164: { workspaceId, phoneE164 } } });
    if (taken && taken.userId !== userId) throw new ConflictException('This phone number is linked to another member');

    const { code, hash } = newLinkCode();
    await this.prisma.whatsAppLink.upsert({
      where: { workspaceId_userId: { workspaceId, userId } },
      create: { workspaceId, userId, phoneE164, linkCodeHash: hash, linkCodeExpiresAt: new Date(Date.now() + LINK_CODE_TTL_MS) },
      update: { phoneE164, verifiedAt: null, linkCodeHash: hash, linkCodeExpiresAt: new Date(Date.now() + LINK_CODE_TTL_MS), failedAttempts: 0 },
    });
    return {
      phoneE164,
      code,
      expiresInMinutes: LINK_CODE_TTL_MS / 60_000,
      instructions: `From ${phoneE164}, send "LINK ${code}" on WhatsApp to ${config.displayPhone ?? 'the business number'} within 15 minutes.`,
    };
  }

  async myLink(workspaceId: string, userId: string) {
    const link = await this.prisma.whatsAppLink.findUnique({ where: { workspaceId_userId: { workspaceId, userId } } });
    return link ? { phoneE164: link.phoneE164, verified: link.verifiedAt !== null, verifiedAt: link.verifiedAt } : null;
  }

  async unlink(workspaceId: string, userId: string) {
    await this.prisma.whatsAppLink.deleteMany({ where: { workspaceId, userId } });
    return { deleted: true };
  }

  listLinks(workspaceId: string) {
    return this.prisma.whatsAppLink.findMany({
      where: { workspaceId },
      select: { id: true, phoneE164: true, verifiedAt: true, createdAt: true, user: { select: { id: true, fullName: true, email: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async removeLink(workspaceId: string, linkId: string) {
    const result = await this.prisma.whatsAppLink.deleteMany({ where: { id: linkId, workspaceId } });
    if (result.count === 0) throw new NotFoundException('Link not found');
    return { deleted: true };
  }

  listMessages(workspaceId: string) {
    return this.prisma.whatsAppMessageLog.findMany({ where: { workspaceId }, orderBy: { createdAt: 'desc' }, take: 200 });
  }

  // --- Webhook ---------------------------------------------------------------------

  /** GET verification handshake: echo the challenge only for a token we issued. */
  async verifyWebhook(mode?: string, token?: string, challenge?: string): Promise<string | null> {
    if (mode !== 'subscribe' || !token || !challenge) return null;
    const config = await this.prisma.whatsAppConfig.findUnique({ where: { verifyToken: token } });
    return config ? challenge : null;
  }

  /**
   * Validates the signature for the workspace the payload is addressed to.
   * Returns the work to do (run after replying 200 to Meta), or null when the
   * request must be rejected.
   */
  async acceptWebhook(rawBody: Buffer | undefined, signature: string | undefined): Promise<(() => Promise<void>) | null> {
    if (!rawBody) return null;
    let payload: WebhookPayload;
    try {
      payload = JSON.parse(rawBody.toString('utf8')) as WebhookPayload;
    } catch {
      return null;
    }
    const phoneNumberIds = new Set(
      (payload.entry ?? []).flatMap((e) => (e.changes ?? []).map((c) => c.value?.metadata?.phone_number_id)).filter((id): id is string => !!id),
    );
    if (phoneNumberIds.size !== 1) return null;
    const config = await this.prisma.whatsAppConfig.findUnique({ where: { phoneNumberId: [...phoneNumberIds][0] } });
    if (!config || !isValidSignature(this.encryption.decrypt(config.appSecretEncrypted), rawBody, signature)) return null;
    if (!config.isEnabled) return async () => undefined;

    const messages = (payload.entry ?? []).flatMap((e) => (e.changes ?? []).flatMap((c) => c.value?.messages ?? []));
    return async () => {
      for (const message of messages) {
        try {
          await this.handleMessage(config, message);
        } catch (error) {
          this.logger.error(`WhatsApp message ${message.id} failed: ${(error as Error).message}`);
        }
      }
    };
  }

  private async handleMessage(config: WhatsAppConfig, message: { id: string; from: string; type: string; text?: { body?: string } }) {
    const phoneE164 = normalizePhone(message.from) ?? `+${message.from}`;
    // Unique waMessageId: Meta retries are recorded (and processed) once.
    try {
      await this.prisma.whatsAppMessageLog.create({
        data: { workspaceId: config.workspaceId, direction: 'INBOUND', waMessageId: message.id, phoneE164, body: message.text?.body?.slice(0, 2000), status: 'RECEIVED' },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') return;
      throw error;
    }
    const finish = (status: 'PROCESSED' | 'IGNORED' | 'FAILED', extra: { error?: string; draftId?: string } = {}) =>
      this.prisma.whatsAppMessageLog.update({ where: { waMessageId: message.id }, data: { status, ...extra } });

    if (message.type !== 'text' || !message.text?.body) {
      await finish('IGNORED', { error: `Unsupported message type: ${message.type}` });
      await this.reply(config, phoneE164, 'Only text messages are supported for now. Please type what happened.');
      return;
    }

    const command = parseCommand(message.text.body);
    const link = await this.prisma.whatsAppLink.findUnique({ where: { workspaceId_phoneE164: { workspaceId: config.workspaceId, phoneE164 } } });

    if (command.type === 'link') {
      const ok =
        link &&
        !link.verifiedAt &&
        link.linkCodeHash === hashLinkCode(command.code) &&
        link.linkCodeExpiresAt !== null &&
        link.linkCodeExpiresAt > new Date() &&
        link.failedAttempts < MAX_LINK_ATTEMPTS;
      if (ok) {
        await this.prisma.whatsAppLink.update({ where: { id: link.id }, data: { verifiedAt: new Date(), linkCodeHash: null, linkCodeExpiresAt: null } });
        await finish('PROCESSED');
        await this.reply(config, phoneE164, `Linked. ${HELP_TEXT}`);
      } else {
        if (link && !link.verifiedAt) {
          const attempts = link.failedAttempts + 1;
          // Too many wrong codes: the code is burned and the user must request a new one in the app.
          await this.prisma.whatsAppLink.update({
            where: { id: link.id },
            data: { failedAttempts: attempts, ...(attempts >= MAX_LINK_ATTEMPTS ? { linkCodeHash: null, linkCodeExpiresAt: null } : {}) },
          });
        }
        await finish('IGNORED', { error: 'Invalid or expired link code' });
        await this.reply(config, phoneE164, 'That code is not valid or has expired. Get a new code in the app (Settings → WhatsApp).');
      }
      return;
    }

    if (!link?.verifiedAt) {
      await finish('IGNORED', { error: 'Phone number is not linked' });
      await this.reply(config, phoneE164, 'This number is not linked to an account. Open the app, go to Settings → WhatsApp, and follow the steps.');
      return;
    }

    if (command.type === 'help') {
      await finish('PROCESSED');
      await this.reply(config, phoneE164, HELP_TEXT);
      return;
    }

    try {
      const draft = await this.ai.draftFromExternalText(config.workspaceId, command.text, phoneE164, link.userId);
      await finish('PROCESSED', { draftId: draft.id });
      await this.reply(config, phoneE164, `Draft created: ${draft.summary}. It will be saved only after someone approves it in the app.`);
    } catch (error) {
      const reason = (error as Error).message;
      await finish('FAILED', { error: reason.slice(0, 500) });
      await this.reply(config, phoneE164, `Could not create a draft: ${reason.split('(')[0].trim()}`);
    }
  }

  /** Sends a text reply through the Graph API and records the outcome. Never throws. */
  private async reply(config: WhatsAppConfig, toE164: string, body: string): Promise<void> {
    let status: 'SENT' | 'FAILED' = 'SENT';
    let error: string | undefined;
    try {
      const response = await fetch(`${this.graphBase}/${encodeURIComponent(config.phoneNumberId)}/messages`, {
        method: 'POST',
        headers: { authorization: `Bearer ${this.encryption.decrypt(config.accessTokenEncrypted)}`, 'content-type': 'application/json' },
        body: JSON.stringify({ messaging_product: 'whatsapp', to: toE164.replace(/^\+/, ''), type: 'text', text: { body: body.slice(0, 4000) } }),
        signal: AbortSignal.timeout(GRAPH_TIMEOUT_MS),
      });
      if (!response.ok) {
        status = 'FAILED';
        const details = (await response.json().catch(() => null)) as { error?: { message?: string } } | null;
        error = `Graph API ${response.status}: ${details?.error?.message ?? response.statusText}`;
      }
    } catch (e) {
      status = 'FAILED';
      error = `Could not reach WhatsApp: ${(e as Error).message}`;
    }
    await this.prisma.whatsAppMessageLog.create({
      data: { workspaceId: config.workspaceId, direction: 'OUTBOUND', phoneE164: toE164, body: body.slice(0, 2000), status, error: error?.slice(0, 500) },
    });
  }
}
