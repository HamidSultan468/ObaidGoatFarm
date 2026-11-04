import { BadGatewayException, BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import type { AiProviderConfig } from '@prisma/client';
import { EncryptionService } from '../../common/crypto/encryption.service.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { DocumentsService } from '../documents/documents.service.js';
import { DraftsService } from '../drafts/drafts.service.js';
import { buildSystemPrompt, todayIn, toDraftProposal, type Extraction, type ExtractionContext } from './extraction.js';
import { extractWithAnthropic, ProviderError, type ExtractionFile } from './providers/anthropic.provider.js';

/** Workspace time zone for "today" (single-country deployment today). */
const WORKSPACE_TIME_ZONE = 'Asia/Karachi';
const CONTEXT_LIMIT = 300;

const CONFIG_FIELDS = {
  id: true,
  provider: true,
  model: true,
  keyHint: true,
  priority: true,
  isEnabled: true,
  monthlyRequestLimit: true,
  createdAt: true,
  updatedAt: true,
} as const;

const startOfMonth = (now = new Date()) => new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));

/**
 * AI-assisted entry. Provider keys are stored encrypted and never returned.
 * Every AI result becomes a PENDING draft; nothing is posted without a
 * person approving it (CLAUDE.md §3). If AI is unavailable, every manual
 * form keeps working - AI is never a dependency.
 */
@Injectable()
export class AiService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly encryption: EncryptionService,
    private readonly documents: DocumentsService,
    private readonly drafts: DraftsService,
  ) {}

  // --- Provider configuration (OWNER/ADMIN) -------------------------------

  listProviders(workspaceId: string) {
    return this.prisma.aiProviderConfig.findMany({ where: { workspaceId }, select: CONFIG_FIELDS, orderBy: { priority: 'asc' } });
  }

  addProvider(workspaceId: string, dto: { apiKey: string; model: string; priority?: number; monthlyRequestLimit?: number | null }) {
    return this.prisma.aiProviderConfig.create({
      data: {
        workspaceId,
        provider: 'ANTHROPIC',
        model: dto.model,
        apiKeyEncrypted: this.encryption.encrypt(dto.apiKey),
        keyHint: dto.apiKey.slice(-4),
        priority: dto.priority ?? 1,
        monthlyRequestLimit: dto.monthlyRequestLimit ?? null,
      },
      select: CONFIG_FIELDS,
    });
  }

  async updateProvider(
    workspaceId: string,
    configId: string,
    dto: { apiKey?: string; model?: string; priority?: number; isEnabled?: boolean; monthlyRequestLimit?: number | null },
  ) {
    await this.requireConfig(workspaceId, configId);
    return this.prisma.aiProviderConfig.update({
      where: { id: configId },
      data: {
        ...(dto.model !== undefined ? { model: dto.model } : {}),
        ...(dto.priority !== undefined ? { priority: dto.priority } : {}),
        ...(dto.isEnabled !== undefined ? { isEnabled: dto.isEnabled } : {}),
        ...(dto.monthlyRequestLimit !== undefined ? { monthlyRequestLimit: dto.monthlyRequestLimit } : {}),
        ...(dto.apiKey ? { apiKeyEncrypted: this.encryption.encrypt(dto.apiKey), keyHint: dto.apiKey.slice(-4) } : {}),
      },
      select: CONFIG_FIELDS,
    });
  }

  async removeProvider(workspaceId: string, configId: string) {
    await this.requireConfig(workspaceId, configId);
    await this.prisma.aiProviderConfig.delete({ where: { id: configId } });
    return { deleted: true };
  }

  /** A real round trip with a tiny prompt, so an owner knows the key and model work. */
  async testProvider(workspaceId: string, configId: string) {
    const config = await this.requireConfig(workspaceId, configId);
    const context: ExtractionContext = { today: todayIn(WORKSPACE_TIME_ZONE), accounts: [], animals: [], landParcels: [], contacts: [] };
    try {
      await this.callProvider(config, 'provider.test', { system: buildSystemPrompt(context), text: 'Connection test: reply with kind UNKNOWN.' });
      return { ok: true, message: `Connected to ${config.model}` };
    } catch (error) {
      return { ok: false, message: (error as Error).message };
    }
  }

  /** This month's usage per provider (requests, failures, tokens). */
  async usage(workspaceId: string) {
    const since = startOfMonth();
    const [configs, rows] = await Promise.all([
      this.listProviders(workspaceId),
      this.prisma.aiUsageLog.groupBy({
        by: ['configId', 'success'],
        where: { workspaceId, createdAt: { gte: since } },
        _count: true,
        _sum: { inputTokens: true, outputTokens: true },
      }),
    ]);
    const perConfig = configs.map((config) => {
      const mine = rows.filter((r) => r.configId === config.id);
      const requests = mine.reduce((n, r) => n + r._count, 0);
      return {
        configId: config.id,
        model: config.model,
        monthlyRequestLimit: config.monthlyRequestLimit,
        requests,
        failures: mine.filter((r) => !r.success).reduce((n, r) => n + r._count, 0),
        inputTokens: mine.reduce((n, r) => n + (r._sum.inputTokens ?? 0), 0),
        outputTokens: mine.reduce((n, r) => n + (r._sum.outputTokens ?? 0), 0),
      };
    });
    return { since: since.toISOString(), providers: perConfig };
  }

  // --- Drafts from text / receipts (record writers) -------------------------

  async draftFromText(workspaceId: string, userId: string, text: string) {
    const context = await this.buildContext(workspaceId);
    const extraction = await this.extract(workspaceId, 'draft.text', context, text);
    return this.saveDraft(workspaceId, userId, extraction, context, { source: 'AI_TEXT', rawInput: text });
  }

  async draftFromReceipt(workspaceId: string, userId: string, attachmentId: string, note?: string) {
    const attachment = await this.prisma.attachment.findFirst({ where: { id: attachmentId, workspaceId } });
    if (!attachment) throw new NotFoundException('Document not found');
    const file: ExtractionFile = {
      mimeType: attachment.mimeType as ExtractionFile['mimeType'],
      base64: (await this.documents.readDecryptedFile(attachment.storageKey)).toString('base64'),
    };
    const context = await this.buildContext(workspaceId);
    const text = `This is a receipt or bill. Create an EXPENSE draft (or INCOME if it is clearly money received) using the total amount.${note ? ` Note from the user: ${note}` : ''}`;
    const extraction = await this.extract(workspaceId, 'draft.receipt', context, text, file);
    return this.saveDraft(workspaceId, userId, extraction, context, { source: 'AI_RECEIPT', rawInput: note ?? attachment.title, attachmentId });
  }

  /** Shared with WhatsApp: text in, PENDING draft (or a reason) out. */
  async draftFromExternalText(workspaceId: string, text: string, sourcePhone: string, userId: string) {
    const context = await this.buildContext(workspaceId);
    const extraction = await this.extract(workspaceId, 'draft.whatsapp', context, text);
    return this.saveDraft(workspaceId, userId, extraction, context, { source: 'WHATSAPP', rawInput: text, sourcePhone });
  }

  private async saveDraft(
    workspaceId: string,
    userId: string,
    extraction: Extraction,
    context: ExtractionContext,
    meta: { source: 'AI_TEXT' | 'AI_RECEIPT' | 'WHATSAPP'; rawInput?: string; attachmentId?: string; sourcePhone?: string },
  ) {
    const proposal = toDraftProposal(extraction, context);
    if (!proposal.ok) {
      throw new BadRequestException(`Could not turn this into a record: ${proposal.reason}`);
    }
    return this.drafts.create({
      workspaceId,
      kind: proposal.kind,
      summary: proposal.summary,
      payload: proposal.payload,
      warnings: proposal.warnings,
      createdByUserId: userId,
      ...meta,
    });
  }

  // --- Internals --------------------------------------------------------------

  private async buildContext(workspaceId: string): Promise<ExtractionContext> {
    const [accounts, animals, landParcels, contacts] = await Promise.all([
      this.prisma.account.findMany({ where: { workspaceId, isActive: true }, select: { id: true, code: true, name: true, type: true, kind: true }, orderBy: { code: 'asc' } }),
      this.prisma.animal.findMany({ where: { workspaceId, status: 'ACTIVE' }, select: { id: true, tagNumber: true, name: true }, orderBy: { tagNumber: 'asc' }, take: CONTEXT_LIMIT }),
      this.prisma.landParcel.findMany({ where: { workspaceId, status: 'ACTIVE' }, select: { id: true, name: true }, take: CONTEXT_LIMIT }),
      this.prisma.contact.findMany({ where: { workspaceId, isActive: true }, select: { id: true, name: true }, take: CONTEXT_LIMIT }),
    ]);
    return { today: todayIn(WORKSPACE_TIME_ZONE), accounts, animals, landParcels, contacts };
  }

  /**
   * Tries enabled providers in priority order, skipping any over its monthly
   * limit, logging every attempt. First success wins (failover).
   */
  private async extract(workspaceId: string, feature: string, context: ExtractionContext, text: string, file?: ExtractionFile): Promise<Extraction> {
    const configs = await this.prisma.aiProviderConfig.findMany({ where: { workspaceId, isEnabled: true }, orderBy: { priority: 'asc' } });
    if (configs.length === 0) {
      throw new BadRequestException('AI is not set up for this workspace. An owner or admin can add an API key in Settings. Manual entry works as usual.');
    }
    const failures: string[] = [];
    for (const config of configs) {
      if (config.monthlyRequestLimit !== null) {
        const used = await this.prisma.aiUsageLog.count({ where: { configId: config.id, createdAt: { gte: startOfMonth() } } });
        if (used >= config.monthlyRequestLimit) {
          failures.push(`${config.model}: monthly limit reached`);
          continue;
        }
      }
      try {
        return (await this.callProvider(config, feature, { system: buildSystemPrompt(context), text, file })) as Extraction;
      } catch (error) {
        failures.push(`${config.model}: ${(error as Error).message}`);
      }
    }
    throw new BadGatewayException(`No AI provider could handle the request (${failures.join('; ')}). Manual entry still works.`);
  }

  private async callProvider(config: AiProviderConfig, feature: string, input: { system: string; text: string; file?: ExtractionFile }) {
    const started = Date.now();
    const log = (data: { success: boolean; inputTokens?: number; outputTokens?: number; error?: string }) =>
      this.prisma.aiUsageLog.create({
        data: { workspaceId: config.workspaceId, configId: config.id, provider: config.provider, model: config.model, feature, latencyMs: Date.now() - started, ...data },
      });
    try {
      const result = await extractWithAnthropic({ apiKey: this.encryption.decrypt(config.apiKeyEncrypted), model: config.model, ...input });
      await log({ success: true, inputTokens: result.inputTokens, outputTokens: result.outputTokens });
      return result.json;
    } catch (error) {
      const message = error instanceof ProviderError ? error.message : 'Unexpected provider error';
      await log({ success: false, error: message.slice(0, 500) });
      throw new Error(message);
    }
  }

  private async requireConfig(workspaceId: string, configId: string) {
    const config = await this.prisma.aiProviderConfig.findFirst({ where: { id: configId, workspaceId } });
    if (!config) throw new NotFoundException('AI provider not found');
    return config;
  }
}
