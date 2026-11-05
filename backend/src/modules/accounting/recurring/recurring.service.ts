import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import type { RecurrenceFrequency } from '@prisma/client';
import { Money } from '../../../common/money/money.js';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { LedgerService } from '../ledger/ledger.service.js';
import type { CreateRecurringTemplateDto } from './dto/create-recurring-template.dto.js';

/**
 * Posting is triggered via an explicit "run now" endpoint — there is no
 * cron/job-scheduler infrastructure in this environment yet to run these
 * unattended. See ACCOUNTING.md and IMPLEMENTATION_STATUS.md.
 */
@Injectable()
export class RecurringService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  /** Every money value in this API is an exact, consistently-formatted decimal string (DECISIONS.md D004) — never a raw Prisma Decimal, whose JSON form can drop trailing zeros. */
  private withExactAmount<T extends { amount: { toString(): string } }>(template: T) {
    return { ...template, amount: Money.from(template.amount.toString()).toFixed(4) };
  }

  async create(workspaceId: string, dto: CreateRecurringTemplateDto) {
    const template = await this.prisma.recurringTemplate.create({
      data: {
        workspaceId,
        name: dto.name,
        entryType: dto.entryType,
        fromAccountId: dto.fromAccountId,
        toAccountId: dto.toAccountId,
        contactId: dto.contactId,
        amount: dto.amount,
        memo: dto.memo,
        frequency: dto.frequency,
        nextRunDate: new Date(dto.nextRunDate),
      },
    });
    return this.withExactAmount(template);
  }

  async findAll(workspaceId: string) {
    const templates = await this.prisma.recurringTemplate.findMany({ where: { workspaceId }, orderBy: { nextRunDate: 'asc' } });
    return templates.map((t) => this.withExactAmount(t));
  }

  async setActive(workspaceId: string, templateId: string, isActive: boolean) {
    const template = await this.require(workspaceId, templateId);
    const updated = await this.prisma.recurringTemplate.update({ where: { id: template.id }, data: { isActive } });
    return this.withExactAmount(updated);
  }

  async runNow(workspaceId: string, templateId: string, userId: string) {
    const template = await this.require(workspaceId, templateId);
    if (!template.isActive) {
      throw new BadRequestException('This recurring template is inactive');
    }

    const entry = await this.ledger.postEntry({
      workspaceId,
      entryType: template.entryType,
      createdByUserId: userId,
      memo: template.memo ?? template.name,
      contactId: template.contactId ?? undefined,
      lines: [
        { accountId: template.toAccountId, amount: template.amount.toString() },
        { accountId: template.fromAccountId, amount: `-${template.amount.toString()}` },
      ],
    });

    await this.prisma.recurringTemplate.update({
      where: { id: template.id },
      data: { nextRunDate: this.advance(template.nextRunDate, template.frequency) },
    });

    return entry;
  }

  private async require(workspaceId: string, templateId: string) {
    const template = await this.prisma.recurringTemplate.findUnique({ where: { id: templateId } });
    if (!template || template.workspaceId !== workspaceId) {
      throw new NotFoundException('Recurring template not found');
    }
    return template;
  }

  private advance(from: Date, frequency: RecurrenceFrequency): Date {
    const next = new Date(from);
    switch (frequency) {
      case 'DAILY':
        next.setDate(next.getDate() + 1);
        break;
      case 'WEEKLY':
        next.setDate(next.getDate() + 7);
        break;
      case 'MONTHLY':
        next.setMonth(next.getMonth() + 1);
        break;
      case 'YEARLY':
        next.setFullYear(next.getFullYear() + 1);
        break;
    }
    return next;
  }
}
