import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { Money } from '../../../common/money/money.js';
import type { CreateContactDto } from './dto/create-contact.dto.js';
import type { UpdateContactDto } from './dto/update-contact.dto.js';

@Injectable()
export class ContactsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(workspaceId: string, dto: CreateContactDto) {
    return this.prisma.contact.create({
      data: {
        workspaceId,
        type: dto.type,
        name: dto.name,
        email: dto.email,
        phone: dto.phone,
        address: dto.address,
        notes: dto.notes,
      },
    });
  }

  async findAll(workspaceId: string) {
    return this.prisma.contact.findMany({ where: { workspaceId }, orderBy: { name: 'asc' } });
  }

  async findOne(workspaceId: string, contactId: string) {
    const contact = await this.prisma.contact.findUnique({ where: { id: contactId } });
    if (!contact || contact.workspaceId !== workspaceId) {
      throw new NotFoundException('Contact not found');
    }
    return contact;
  }

  async update(workspaceId: string, contactId: string, dto: UpdateContactDto) {
    await this.findOne(workspaceId, contactId);
    return this.prisma.contact.update({ where: { id: contactId }, data: dto });
  }

  async setActive(workspaceId: string, contactId: string, isActive: boolean) {
    await this.findOne(workspaceId, contactId);
    return this.prisma.contact.update({ where: { id: contactId }, data: { isActive } });
  }

  /** A contact's "ledger": every posted journal entry tagged with them, newest first, plus a running total. */
  async getLedger(workspaceId: string, contactId: string) {
    await this.findOne(workspaceId, contactId);

    const entries = await this.prisma.journalEntry.findMany({
      where: { workspaceId, contactId, status: 'POSTED' },
      include: { lines: { include: { account: true } } },
      orderBy: { postedAt: 'asc' },
    });

    const total = Money.sum(
      entries.flatMap((entry) => entry.lines.map((line) => Money.from(line.amount.toString()))),
    );

    return { entries, totalNet: total.toFixed(4) };
  }
}
