import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { Money } from '../../../common/money/money.js';
import type { CreateAccountDto } from './dto/create-account.dto.js';

/** Seeded once per new workspace so the dashboard and first transactions have somewhere real to post to. */
const DEFAULT_CHART_OF_ACCOUNTS: Array<Omit<Prisma.AccountCreateManyInput, 'workspaceId'>> = [
  { code: '1000', name: 'Cash', type: 'ASSET', kind: 'CASH', isSystemAccount: true },
  { code: '1010', name: 'Bank Account', type: 'ASSET', kind: 'BANK', isSystemAccount: true },
  { code: '1200', name: 'Accounts Receivable', type: 'ASSET', kind: 'RECEIVABLE', isSystemAccount: true },
  { code: '2000', name: 'Accounts Payable', type: 'LIABILITY', kind: 'PAYABLE', isSystemAccount: true },
  { code: '3000', name: "Owner's Equity", type: 'EQUITY', kind: 'GENERAL', isSystemAccount: true },
  { code: '4000', name: 'Sales Income', type: 'INCOME', kind: 'GENERAL', isSystemAccount: true },
  { code: '5000', name: 'General Expense', type: 'EXPENSE', kind: 'GENERAL', isSystemAccount: true },
];

@Injectable()
export class AccountsService {
  constructor(private readonly prisma: PrismaService) {}

  async seedDefaultChartOfAccounts(workspaceId: string): Promise<void> {
    await this.prisma.account.createMany({
      data: DEFAULT_CHART_OF_ACCOUNTS.map((account) => ({ ...account, workspaceId })),
    });
  }

  async create(workspaceId: string, dto: CreateAccountDto) {
    const existing = await this.prisma.account.findUnique({
      where: { workspaceId_code: { workspaceId, code: dto.code } },
    });
    if (existing) {
      throw new ConflictException('An account with this code already exists');
    }

    return this.prisma.account.create({
      data: { workspaceId, code: dto.code, name: dto.name, type: dto.type, kind: dto.kind },
    });
  }

  async findAll(workspaceId: string) {
    return this.prisma.account.findMany({ where: { workspaceId }, orderBy: { code: 'asc' } });
  }

  async findOne(workspaceId: string, accountId: string) {
    const account = await this.prisma.account.findUnique({ where: { id: accountId } });
    if (!account || account.workspaceId !== workspaceId) {
      throw new NotFoundException('Account not found');
    }
    return account;
  }

  async setActive(workspaceId: string, accountId: string, isActive: boolean) {
    const account = await this.findOne(workspaceId, accountId);
    if (account.isSystemAccount && !isActive) {
      throw new BadRequestException('System accounts cannot be deactivated');
    }
    return this.prisma.account.update({ where: { id: account.id }, data: { isActive } });
  }

  /** Sum of all POSTED journal lines on this account — its current ledger balance. */
  async getBalance(workspaceId: string, accountId: string): Promise<Money> {
    await this.findOne(workspaceId, accountId);
    const lines = await this.prisma.journalLine.findMany({
      where: { accountId, journalEntry: { status: 'POSTED' } },
      select: { amount: true },
    });
    return Money.sum(lines.map((line) => Money.from(line.amount.toString())));
  }

  /**
   * Chronological POSTED lines on this account with a running balance —
   * the basis for both a generic account statement and a "cashbook" view
   * (a cashbook is just this, filtered to a CASH/BANK-kind account).
   */
  async getStatement(workspaceId: string, accountId: string, from?: Date, to?: Date) {
    await this.findOne(workspaceId, accountId);

    const lines = await this.prisma.journalLine.findMany({
      where: {
        accountId,
        journalEntry: {
          status: 'POSTED',
          postedAt: { gte: from, lte: to },
        },
      },
      include: { journalEntry: true },
      orderBy: { journalEntry: { postedAt: 'asc' } },
    });

    let runningBalance = Money.zero();
    const rows = lines.map((line) => {
      runningBalance = runningBalance.add(Money.from(line.amount.toString()));
      return {
        id: line.id,
        journalEntryId: line.journalEntryId,
        postedAt: line.journalEntry.postedAt,
        memo: line.journalEntry.memo,
        documentNumber: line.journalEntry.documentNumber,
        amount: line.amount.toString(),
        runningBalance: runningBalance.toFixed(4),
        reconciledAt: line.reconciledAt,
      };
    });

    return { accountId, rows, closingBalance: runningBalance.toFixed(4) };
  }

  /** Bank reconciliation: marks (or clears) one line as matched against a real bank statement. Never changes the amount — it's purely a checklist flag. */
  async setLineReconciled(workspaceId: string, accountId: string, lineId: string, reconciled: boolean) {
    await this.findOne(workspaceId, accountId);
    const line = await this.prisma.journalLine.findUnique({ where: { id: lineId } });
    if (!line || line.accountId !== accountId) {
      throw new NotFoundException('Journal line not found on this account');
    }
    return this.prisma.journalLine.update({
      where: { id: lineId },
      data: { reconciledAt: reconciled ? new Date() : null },
      select: { id: true, reconciledAt: true },
    });
  }
}
