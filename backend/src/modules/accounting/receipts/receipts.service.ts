import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { Money } from '../../../common/money/money.js';

export interface VerifiedReceipt {
  valid: true;
  documentNumber: string | null;
  memo: string | null;
  amount: string;
  postedAt: string;
  workspaceName: string;
}

@Injectable()
export class ReceiptsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Public lookup by an opaque code embedded in a QR code — deliberately
   * returns only what a receipt holder needs to confirm authenticity, never
   * internal ids or anything else about the issuing workspace's finances.
   */
  async verify(code: string): Promise<VerifiedReceipt> {
    const entry = await this.prisma.journalEntry.findUnique({
      where: { verificationCode: code },
      include: { lines: true, workspace: true },
    });

    if (!entry || entry.status !== 'POSTED' || !entry.postedAt) {
      throw new NotFoundException('No verified receipt found for this code');
    }

    const debitTotal = Money.sum(
      entry.lines
        .map((line) => Money.from(line.amount.toString()))
        .filter((amount) => !amount.isNegative()),
    );

    return {
      valid: true,
      documentNumber: entry.documentNumber,
      memo: entry.memo,
      amount: debitTotal.toFixed(4),
      postedAt: entry.postedAt.toISOString(),
      workspaceName: entry.workspace.name,
    };
  }
}
