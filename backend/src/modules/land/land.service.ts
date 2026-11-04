import { BadRequestException, Injectable, NotFoundException, PreconditionFailedException } from '@nestjs/common';
import { versionMatches } from '../../common/idempotency/idempotency.util.js';
import type { LandParcel } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service.js';
import { computeProfitability } from '../accounting/reports/tagged-profitability.util.js';
import { acreKanalMarla, convertArea, toSquareFeet } from './area.util.js';
import type { CreateLandParcelDto, UpdateLandParcelDto } from './dto/land.dto.js';

const toDate = (value?: string) => (value ? new Date(value) : undefined);

@Injectable()
export class LandService {
  constructor(private readonly prisma: PrismaService) {}

  async create(workspaceId: string, dto: CreateLandParcelDto) {
    this.assertPositiveArea(dto.areaValue);
    this.assertLeaseDates(dto.leaseStartDate, dto.leaseEndDate);
    await this.assertContact(workspaceId, dto.counterpartyContactId);
    const parcel = await this.prisma.landParcel.create({
      data: {
        workspaceId,
        name: dto.name,
        location: dto.location,
        surveyNumber: dto.surveyNumber,
        tenure: dto.tenure,
        ownerName: dto.ownerName,
        areaValue: dto.areaValue,
        areaUnit: dto.areaUnit,
        areaSqFt: toSquareFeet(dto.areaValue, dto.areaUnit),
        landUse: dto.landUse,
        acquisitionDate: toDate(dto.acquisitionDate),
        counterpartyContactId: dto.counterpartyContactId,
        leaseStartDate: toDate(dto.leaseStartDate),
        leaseEndDate: toDate(dto.leaseEndDate),
        leaseTerms: dto.leaseTerms,
        notes: dto.notes,
      },
    });
    return this.withArea(parcel);
  }

  async findAll(workspaceId: string, status?: string) {
    const parcels = await this.prisma.landParcel.findMany({
      where: { workspaceId, ...(status && status !== 'ALL' ? { status: status as LandParcel['status'] } : {}) },
      orderBy: { name: 'asc' },
    });
    return parcels.map((parcel) => this.withArea(parcel));
  }

  async findOne(workspaceId: string, parcelId: string) {
    const parcel = await this.prisma.landParcel.findFirst({
      where: { id: parcelId, workspaceId },
      include: { counterparty: { select: { id: true, name: true, phone: true } } },
    });
    if (!parcel) {
      throw new NotFoundException('Land parcel not found');
    }
    return this.withArea(parcel);
  }

  /** `ifMatch` = the `updatedAt` the client edited from; a newer version on the server -> 412, nothing changed. */
  async update(workspaceId: string, parcelId: string, dto: UpdateLandParcelDto, ifMatch?: string) {
    const existing = await this.requireParcel(workspaceId, parcelId);
    if (!versionMatches(ifMatch, existing.updatedAt)) {
      throw new PreconditionFailedException('This land record was changed by someone else since you opened it. Reload it and apply your change again.');
    }
    if ((dto.areaValue === undefined) !== (dto.areaUnit === undefined)) {
      throw new BadRequestException('Send areaValue and areaUnit together');
    }
    if (dto.areaValue !== undefined) this.assertPositiveArea(dto.areaValue);
    this.assertLeaseDates(
      dto.leaseStartDate ?? existing.leaseStartDate?.toISOString(),
      dto.leaseEndDate ?? existing.leaseEndDate?.toISOString(),
    );
    await this.assertContact(workspaceId, dto.counterpartyContactId);

    const parcel = await this.prisma.landParcel.update({
      where: { id: parcelId },
      data: {
        ...dto,
        ...(dto.areaValue && dto.areaUnit ? { areaSqFt: toSquareFeet(dto.areaValue, dto.areaUnit) } : {}),
        acquisitionDate: toDate(dto.acquisitionDate),
        leaseStartDate: toDate(dto.leaseStartDate),
        leaseEndDate: toDate(dto.leaseEndDate),
      },
    });
    return this.withArea(parcel);
  }

  /** Every POSTED entry tagged with this parcel, plus income/expense/net. */
  async getLedger(workspaceId: string, parcelId: string) {
    await this.requireParcel(workspaceId, parcelId);
    const entries = await this.prisma.journalEntry.findMany({
      where: { workspaceId, landParcelId: parcelId, status: 'POSTED' },
      include: { lines: { include: { account: true } } },
      orderBy: { postedAt: 'desc' },
    });
    return { entries, ...computeProfitability(entries) };
  }

  /** Profitability per parcel (FR-7: "separate land accounts and profitability reports per property"). */
  async getProfitabilityReport(workspaceId: string, from?: string, to?: string) {
    const postedAt = from || to ? { ...(from ? { gte: new Date(from) } : {}), ...(to ? { lte: new Date(to) } : {}) } : undefined;
    const [parcels, entries] = await Promise.all([
      this.prisma.landParcel.findMany({ where: { workspaceId }, orderBy: { name: 'asc' } }),
      this.prisma.journalEntry.findMany({
        where: { workspaceId, status: 'POSTED', landParcelId: { not: null }, ...(postedAt ? { postedAt } : {}) },
        include: { lines: { include: { account: true } } },
      }),
    ]);
    const rows = parcels.map((parcel) => ({
      parcel: { id: parcel.id, name: parcel.name, status: parcel.status, tenure: parcel.tenure },
      ...computeProfitability(entries.filter((entry) => entry.landParcelId === parcel.id)),
    }));
    return { rows, total: computeProfitability(entries) };
  }

  private withArea<T extends LandParcel>(parcel: T) {
    const sqFt = parcel.areaSqFt.toString();
    return { ...parcel, areaConversions: convertArea(sqFt), areaBreakdown: acreKanalMarla(sqFt) };
  }

  private async requireParcel(workspaceId: string, parcelId: string) {
    const parcel = await this.prisma.landParcel.findFirst({ where: { id: parcelId, workspaceId } });
    if (!parcel) {
      throw new NotFoundException('Land parcel not found');
    }
    return parcel;
  }

  private assertPositiveArea(value: string) {
    if (/^0+(\.0+)?$/.test(value)) {
      throw new BadRequestException('areaValue must be greater than zero');
    }
  }

  private assertLeaseDates(start?: string, end?: string) {
    if (start && end && new Date(end) < new Date(start)) {
      throw new BadRequestException('leaseEndDate cannot be before leaseStartDate');
    }
  }

  private async assertContact(workspaceId: string, contactId?: string) {
    if (!contactId) return;
    const count = await this.prisma.contact.count({ where: { id: contactId, workspaceId } });
    if (count !== 1) {
      throw new BadRequestException('Invalid contact');
    }
  }
}
