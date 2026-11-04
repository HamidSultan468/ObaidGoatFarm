import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { Money } from '../../../common/money/money.js';
import { LedgerService } from '../ledger/ledger.service.js';
import type { CreateManualEntryDto } from './dto/create-manual-entry.dto.js';
import type { RecordExpenseDto } from './dto/record-expense.dto.js';
import type { RecordIncomeDto } from './dto/record-income.dto.js';
import type { RecordTransferDto } from './dto/record-transfer.dto.js';

@Injectable()
export class TransactionsService {
  constructor(
    private readonly ledger: LedgerService,
    private readonly prisma: PrismaService,
  ) {}

  async recordIncome(workspaceId: string, userId: string, dto: RecordIncomeDto) {
    const amount = Money.from(dto.amount);
    return this.ledger.postEntry({
      workspaceId,
      entryType: 'INCOME',
      createdByUserId: userId,
      memo: dto.memo,
      documentNumber: dto.documentNumber,
      contactId: dto.contactId,
      animalId: dto.animalId,
      landParcelId: dto.landParcelId,
      issueReceipt: dto.issueReceipt,
      lines: [
        { accountId: dto.toAccountId, amount: amount.toFixed(4) },
        { accountId: dto.incomeAccountId, amount: amount.negate().toFixed(4) },
      ],
    });
  }

  async recordExpense(workspaceId: string, userId: string, dto: RecordExpenseDto) {
    const amount = Money.from(dto.amount);
    return this.ledger.postEntry({
      workspaceId,
      entryType: 'EXPENSE',
      createdByUserId: userId,
      memo: dto.memo,
      documentNumber: dto.documentNumber,
      contactId: dto.contactId,
      animalId: dto.animalId,
      landParcelId: dto.landParcelId,
      lines: [
        { accountId: dto.expenseAccountId, amount: amount.toFixed(4) },
        { accountId: dto.fromAccountId, amount: amount.negate().toFixed(4) },
      ],
    });
  }

  async recordTransfer(workspaceId: string, userId: string, dto: RecordTransferDto) {
    const amount = Money.from(dto.amount);
    return this.ledger.postEntry({
      workspaceId,
      entryType: 'TRANSFER',
      createdByUserId: userId,
      memo: dto.memo,
      lines: [
        { accountId: dto.toAccountId, amount: amount.toFixed(4) },
        { accountId: dto.fromAccountId, amount: amount.negate().toFixed(4) },
      ],
    });
  }

  async createManualEntry(workspaceId: string, userId: string, dto: CreateManualEntryDto) {
    return this.ledger.postEntry({
      workspaceId,
      entryType: 'MANUAL',
      createdByUserId: userId,
      memo: dto.memo,
      documentNumber: dto.documentNumber,
      contactId: dto.contactId,
      animalId: dto.animalId,
      landParcelId: dto.landParcelId,
      lines: dto.lines,
    });
  }

  async findAll(workspaceId: string, limit = 50) {
    return this.prisma.journalEntry.findMany({
      where: { workspaceId },
      include: { lines: { include: { account: true } }, contact: true },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async findOne(workspaceId: string, entryId: string) {
    return this.prisma.journalEntry.findFirstOrThrow({
      where: { id: entryId, workspaceId },
      include: { lines: { include: { account: true } }, contact: true },
    });
  }

  reverse(workspaceId: string, entryId: string, userId: string) {
    return this.ledger.reverseEntry(entryId, workspaceId, userId);
  }

  approve(workspaceId: string, entryId: string, approverId: string) {
    return this.ledger.approveEntry(entryId, workspaceId, approverId);
  }

  reject(workspaceId: string, entryId: string, approverId: string) {
    return this.ledger.rejectEntry(entryId, workspaceId, approverId);
  }

  listPendingApprovals(workspaceId: string) {
    return this.ledger.listPendingApprovals(workspaceId);
  }
}
