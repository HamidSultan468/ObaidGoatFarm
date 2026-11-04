import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import type { JournalEntry, JournalEntryType, Prisma } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { Money } from '../../../common/money/money.js';
import { assertBalanced } from './balance.util.js';

export interface PostLineInput {
  accountId: string;
  /** Positive = debit, negative = credit. */
  amount: string;
}

export interface PostEntryInput {
  workspaceId: string;
  entryType: JournalEntryType;
  lines: PostLineInput[];
  memo?: string;
  documentNumber?: string;
  contactId?: string;
  /** Optional Goat Farm / Land tags for per-animal and per-parcel profitability. */
  animalId?: string;
  landParcelId?: string;
  createdByUserId: string;
  /** INCOME/INVOICE/PAYMENT_RECEIVED entries get a QR-verifiable receipt code. */
  issueReceipt?: boolean;
}

const VERIFICATION_CODE_BYTES = 16;

/**
 * The single place every financial record in the platform posts through —
 * Phase 06/07 (goat farm, land) income/expenses must go through this too,
 * not maintain a parallel ledger (see ACCOUNTING.md).
 */
@Injectable()
export class LedgerService {
  constructor(private readonly prisma: PrismaService) {}

  async postEntry(input: PostEntryInput): Promise<JournalEntry> {
    assertBalanced(input.lines);
    await this.assertReferencesBelongToWorkspace(input);

    const workspace = await this.prisma.workspace.findUniqueOrThrow({ where: { id: input.workspaceId } });
    const requiresApproval = this.exceedsApprovalThreshold(input.lines, workspace.approvalThreshold?.toString());

    const data: Prisma.JournalEntryCreateInput = {
      workspace: { connect: { id: input.workspaceId } },
      entryType: input.entryType,
      status: requiresApproval ? 'PENDING_APPROVAL' : 'POSTED',
      memo: input.memo,
      documentNumber: input.documentNumber,
      contact: input.contactId ? { connect: { id: input.contactId } } : undefined,
      animal: input.animalId ? { connect: { id: input.animalId } } : undefined,
      landParcel: input.landParcelId ? { connect: { id: input.landParcelId } } : undefined,
      createdByUserId: input.createdByUserId,
      postedAt: requiresApproval ? null : new Date(),
      verificationCode: input.issueReceipt ? randomBytes(VERIFICATION_CODE_BYTES).toString('hex') : undefined,
      lines: {
        create: input.lines.map((line) => ({
          account: { connect: { id: line.accountId } },
          amount: line.amount,
        })),
      },
    };

    return this.prisma.journalEntry.create({ data, include: { lines: true } });
  }

  async reverseEntry(entryId: string, workspaceId: string, userId: string): Promise<JournalEntry> {
    const original = await this.prisma.journalEntry.findUnique({
      where: { id: entryId },
      include: { lines: true },
    });

    if (!original || original.workspaceId !== workspaceId) {
      throw new NotFoundException('Journal entry not found');
    }
    if (original.status !== 'POSTED') {
      throw new BadRequestException('Only a posted entry can be reversed');
    }
    const alreadyReversed = await this.prisma.journalEntry.findUnique({ where: { reversalOfId: entryId } });
    if (alreadyReversed) {
      throw new BadRequestException('This entry has already been reversed');
    }

    return this.prisma.journalEntry.create({
      data: {
        workspace: { connect: { id: workspaceId } },
        entryType: original.entryType,
        status: 'POSTED',
        memo: original.memo ? `Reversal of: ${original.memo}` : 'Reversal',
        contact: original.contactId ? { connect: { id: original.contactId } } : undefined,
        animal: original.animalId ? { connect: { id: original.animalId } } : undefined,
        landParcel: original.landParcelId ? { connect: { id: original.landParcelId } } : undefined,
        createdByUserId: userId,
        postedAt: new Date(),
        reversalOf: { connect: { id: entryId } },
        lines: {
          create: original.lines.map((line) => ({
            accountId: line.accountId,
            amount: Money.from(line.amount.toString()).negate().toFixed(4),
          })),
        },
      },
      include: { lines: true },
    });
  }

  async approveEntry(entryId: string, workspaceId: string, approverId: string): Promise<JournalEntry> {
    const entry = await this.requirePendingEntry(entryId, workspaceId);
    return this.prisma.journalEntry.update({
      where: { id: entry.id },
      data: { status: 'POSTED', postedAt: new Date(), approvedByUserId: approverId, approvedAt: new Date() },
    });
  }

  async rejectEntry(entryId: string, workspaceId: string, approverId: string): Promise<JournalEntry> {
    const entry = await this.requirePendingEntry(entryId, workspaceId);
    return this.prisma.journalEntry.update({
      where: { id: entry.id },
      data: { status: 'REJECTED', approvedByUserId: approverId, approvedAt: new Date() },
    });
  }

  async listPendingApprovals(workspaceId: string) {
    return this.prisma.journalEntry.findMany({
      where: { workspaceId, status: 'PENDING_APPROVAL' },
      include: { lines: { include: { account: true } }, contact: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  private async requirePendingEntry(entryId: string, workspaceId: string): Promise<JournalEntry> {
    const entry = await this.prisma.journalEntry.findUnique({ where: { id: entryId } });
    if (!entry || entry.workspaceId !== workspaceId) {
      throw new NotFoundException('Journal entry not found');
    }
    if (entry.status !== 'PENDING_APPROVAL') {
      throw new ForbiddenException('This entry is not awaiting approval');
    }
    return entry;
  }

  private exceedsApprovalThreshold(lines: PostLineInput[], threshold?: string): boolean {
    if (!threshold) return false;
    const debitTotal = Money.sum(
      lines.map((line) => Money.from(line.amount)).filter((amount) => !amount.isNegative()),
    );
    return debitTotal.compareTo(Money.from(threshold)) >= 0;
  }

  /**
   * Tenant isolation for the single ledger write path: every account,
   * contact, animal and land parcel an entry references must belong to the
   * entry's workspace (accounts must also be active). Without this, a caller
   * could post against another tenant's records just by knowing an id.
   * Responds 400 without revealing whether the foreign id exists.
   */
  private async assertReferencesBelongToWorkspace(input: PostEntryInput): Promise<void> {
    const { workspaceId } = input;
    const accountIds = [...new Set(input.lines.map((line) => line.accountId))];
    const ownedActiveAccounts = await this.prisma.account.count({
      where: { id: { in: accountIds }, workspaceId, isActive: true },
    });
    if (ownedActiveAccounts !== accountIds.length) {
      throw new BadRequestException('One or more accounts are invalid or inactive');
    }

    const checks: Array<[string | undefined, () => Promise<number>, string]> = [
      [input.contactId, () => this.prisma.contact.count({ where: { id: input.contactId, workspaceId } }), 'contact'],
      [input.animalId, () => this.prisma.animal.count({ where: { id: input.animalId, workspaceId } }), 'animal'],
      [
        input.landParcelId,
        () => this.prisma.landParcel.count({ where: { id: input.landParcelId, workspaceId } }),
        'land parcel',
      ],
    ];
    for (const [id, count, label] of checks) {
      if (id && (await count()) !== 1) {
        throw new BadRequestException(`Invalid ${label}`);
      }
    }
  }
}
