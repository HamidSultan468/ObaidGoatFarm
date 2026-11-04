import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { Money } from '../../../common/money/money.js';
import type { CreateBudgetDto } from './dto/create-budget.dto.js';

@Injectable()
export class BudgetsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(workspaceId: string, dto: CreateBudgetDto) {
    const account = await this.prisma.account.findUnique({ where: { id: dto.accountId } });
    if (!account || account.workspaceId !== workspaceId) {
      throw new NotFoundException('Account not found');
    }

    return this.prisma.budget.create({
      data: {
        workspaceId,
        accountId: dto.accountId,
        periodStart: new Date(dto.periodStart),
        periodEnd: new Date(dto.periodEnd),
        amount: dto.amount,
      },
    });
  }

  async findAll(workspaceId: string) {
    return this.prisma.budget.findMany({
      where: { workspaceId },
      include: { account: true },
      orderBy: { periodStart: 'desc' },
    });
  }

  /** Budgeted amount vs. actual POSTED activity on that account within the budget's own period. */
  async getProgress(workspaceId: string, budgetId: string) {
    const budget = await this.prisma.budget.findUnique({ where: { id: budgetId }, include: { account: true } });
    if (!budget || budget.workspaceId !== workspaceId) {
      throw new NotFoundException('Budget not found');
    }

    const lines = await this.prisma.journalLine.findMany({
      where: {
        accountId: budget.accountId,
        journalEntry: { status: 'POSTED', postedAt: { gte: budget.periodStart, lte: budget.periodEnd } },
      },
      select: { amount: true },
    });

    const actualRaw = Money.sum(lines.map((line) => Money.from(line.amount.toString())));
    // Normalize to a positive "amount spent/earned" figure regardless of the account's natural debit/credit sign.
    const actual = actualRaw.isNegative() ? actualRaw.negate() : actualRaw;
    const budgeted = Money.from(budget.amount.toString());

    return {
      budget,
      actual: actual.toFixed(4),
      remaining: budgeted.subtract(actual).toFixed(4),
      percentUsed: budgeted.isZero() ? null : actual.toDecimal().div(budgeted.toDecimal()).times(100).toFixed(2),
    };
  }
}
