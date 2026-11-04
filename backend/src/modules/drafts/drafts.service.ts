import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import type { DraftKind, DraftSource, Prisma } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { PrismaService } from '../../prisma/prisma.service.js';
import { RecordExpenseDto } from '../accounting/transactions/dto/record-expense.dto.js';
import { RecordIncomeDto } from '../accounting/transactions/dto/record-income.dto.js';
import { TransactionsService } from '../accounting/transactions/transactions.service.js';
import { AnimalsService } from '../farm/animals/animals.service.js';
import { CreateHealthRecordDto, CreateWeightRecordDto } from '../farm/animals/dto/records.dto.js';
import { NotificationsService } from '../notifications/notifications.service.js';

export interface NewDraft {
  workspaceId: string;
  source: DraftSource;
  kind: DraftKind;
  summary: string;
  payload: Record<string, unknown>;
  warnings?: string[];
  rawInput?: string;
  attachmentId?: string;
  sourcePhone?: string;
  createdByUserId?: string;
}

const PUBLIC_FIELDS = {
  id: true,
  source: true,
  kind: true,
  status: true,
  summary: true,
  payload: true,
  rawInput: true,
  warnings: true,
  attachmentId: true,
  sourcePhone: true,
  createdByUserId: true,
  reviewedByUserId: true,
  reviewedAt: true,
  rejectReason: true,
  resultType: true,
  resultId: true,
  createdAt: true,
} as const;

/** Drops null/empty values so optional DTO fields are simply absent. */
const compact = (payload: Record<string, unknown>) =>
  Object.fromEntries(Object.entries(payload).filter(([, value]) => value !== null && value !== undefined && value !== ''));

async function validated<T extends object>(dtoClass: new () => T, plain: Record<string, unknown>): Promise<T> {
  const instance = plainToInstance(dtoClass, plain);
  const errors = await validate(instance, { whitelist: true, forbidNonWhitelisted: true });
  if (errors.length > 0) {
    throw new BadRequestException({
      message: 'The draft is incomplete or invalid. Fix the highlighted fields and approve again.',
      errors: errors.flatMap((e) => Object.values(e.constraints ?? {})),
    });
  }
  return instance;
}

/**
 * Drafts from AI or WhatsApp. Approval is the only way a draft becomes a
 * record, and it goes through exactly the same services (and therefore the
 * same validation, ledger balancing, approval threshold and tenant checks)
 * as manual entry.
 */
@Injectable()
export class DraftsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly transactions: TransactionsService,
    private readonly animals: AnimalsService,
    private readonly notifications: NotificationsService,
  ) {}

  async create(draft: NewDraft) {
    const created = await this.prisma.recordDraft.create({
      data: {
        workspaceId: draft.workspaceId,
        source: draft.source,
        kind: draft.kind,
        summary: draft.summary.slice(0, 300),
        payload: draft.payload as Prisma.InputJsonValue,
        warnings: (draft.warnings ?? []) as Prisma.InputJsonValue,
        rawInput: draft.rawInput?.slice(0, 2000),
        attachmentId: draft.attachmentId,
        sourcePhone: draft.sourcePhone,
        createdByUserId: draft.createdByUserId,
      },
      select: PUBLIC_FIELDS,
    });
    // Someone typing in the app sees their draft immediately; drafts arriving
    // from outside (WhatsApp) notify the reviewers chosen in the DRAFTS rule.
    if (draft.source === 'WHATSAPP') {
      await this.notifications.notifyByRule(draft.workspaceId, {
        category: 'DRAFTS',
        title: 'New draft from WhatsApp',
        body: `${created.summary}. Review and approve it before it is saved.`,
        link: '/ai-assistant',
        dedupeKey: `draft:${created.id}`,
      });
    }
    return created;
  }

  list(workspaceId: string, status?: string) {
    return this.prisma.recordDraft.findMany({
      where: { workspaceId, ...(status ? { status: status as Prisma.EnumDraftStatusFilter['equals'] } : {}) },
      select: PUBLIC_FIELDS,
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async get(workspaceId: string, draftId: string) {
    const draft = await this.prisma.recordDraft.findFirst({ where: { id: draftId, workspaceId }, select: PUBLIC_FIELDS });
    if (!draft) throw new NotFoundException('Draft not found');
    return draft;
  }

  /**
   * Approves (optionally with the reviewer's corrected payload) and creates
   * the real record. The PENDING -> APPROVED claim is a single conditional
   * update, so a double click or two reviewers can never create it twice.
   * If creating the record fails, the draft goes back to PENDING.
   */
  async approve(workspaceId: string, draftId: string, userId: string, editedPayload?: Record<string, unknown>) {
    const draft = await this.prisma.recordDraft.findFirst({ where: { id: draftId, workspaceId } });
    if (!draft) throw new NotFoundException('Draft not found');
    if (draft.status !== 'PENDING') throw new ConflictException(`This draft was already ${draft.status.toLowerCase()}`);

    const payload = compact(editedPayload ?? (draft.payload as Record<string, unknown>));
    // Validate before claiming, so an incomplete draft stays PENDING with a clear message.
    const action = await this.prepare(draft.kind, payload, draft.summary);

    const claimed = await this.prisma.recordDraft.updateMany({
      where: { id: draftId, workspaceId, status: 'PENDING' },
      data: { status: 'APPROVED', reviewedByUserId: userId, reviewedAt: new Date(), payload: payload as Prisma.InputJsonValue },
    });
    if (claimed.count !== 1) throw new ConflictException('This draft was just reviewed by someone else');

    try {
      const result = await action(workspaceId, userId);
      await this.prisma.recordDraft.update({ where: { id: draftId }, data: { resultType: result.type, resultId: result.id } });
      return { draft: await this.get(workspaceId, draftId), result };
    } catch (error) {
      await this.prisma.recordDraft.update({
        where: { id: draftId },
        data: { status: 'PENDING', reviewedByUserId: null, reviewedAt: null },
      });
      throw error;
    }
  }

  async reject(workspaceId: string, draftId: string, userId: string, reason?: string) {
    const result = await this.prisma.recordDraft.updateMany({
      where: { id: draftId, workspaceId, status: 'PENDING' },
      data: { status: 'REJECTED', reviewedByUserId: userId, reviewedAt: new Date(), rejectReason: reason?.slice(0, 500) },
    });
    if (result.count !== 1) {
      await this.get(workspaceId, draftId); // 404 if it doesn't exist
      throw new ConflictException('This draft was already reviewed');
    }
    return this.get(workspaceId, draftId);
  }

  /** Validates the payload with the same DTOs as manual entry and returns the action that creates the record. */
  private async prepare(
    kind: DraftKind,
    payload: Record<string, unknown>,
    summary: string,
  ): Promise<(workspaceId: string, userId: string) => Promise<{ type: string; id: string; status?: string }>> {
    switch (kind) {
      case 'INCOME': {
        const dto = await validated(RecordIncomeDto, { memo: summary, ...payload });
        return async (ws, user) => {
          const entry = await this.transactions.recordIncome(ws, user, dto);
          return { type: 'JournalEntry', id: entry.id, status: entry.status };
        };
      }
      case 'EXPENSE': {
        const dto = await validated(RecordExpenseDto, { memo: summary, ...payload });
        return async (ws, user) => {
          const entry = await this.transactions.recordExpense(ws, user, dto);
          return { type: 'JournalEntry', id: entry.id, status: entry.status };
        };
      }
      case 'ANIMAL_HEALTH': {
        const { animalId, ...rest } = payload;
        if (typeof animalId !== 'string') throw new BadRequestException({ message: 'Choose the animal before approving.', errors: ['animalId is required'] });
        const dto = await validated(CreateHealthRecordDto, rest);
        return async (ws, user) => {
          const record = await this.animals.addHealthRecord(ws, animalId, user, dto);
          return { type: 'AnimalHealthRecord', id: record.id };
        };
      }
      case 'ANIMAL_WEIGHT': {
        const { animalId, ...rest } = payload;
        if (typeof animalId !== 'string') throw new BadRequestException({ message: 'Choose the animal before approving.', errors: ['animalId is required'] });
        const dto = await validated(CreateWeightRecordDto, rest);
        return async (ws) => {
          const record = await this.animals.addWeight(ws, animalId, dto);
          return { type: 'AnimalWeightRecord', id: record.id };
        };
      }
    }
  }
}
