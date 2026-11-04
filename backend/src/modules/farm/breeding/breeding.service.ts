import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { AnimalsService } from '../animals/animals.service.js';
import type { CreateBreedingDto, RecordKiddingDto, UpdateBreedingStatusDto } from './dto/breeding.dto.js';
import { canRecordKidding, canTransition, expectedKiddingDate } from './gestation.util.js';

const ANIMAL_SUMMARY = { id: true, tagNumber: true, name: true } as const;

@Injectable()
export class BreedingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly animals: AnimalsService,
  ) {}

  async create(workspaceId: string, dto: CreateBreedingDto) {
    if (dto.sireId && dto.externalSire) {
      throw new BadRequestException('Give either sireId or externalSire, not both');
    }
    const dam = await this.animals.requireAnimal(workspaceId, dto.damId).catch(() => {
      throw new BadRequestException('Invalid dam');
    });
    if (dam.status !== 'ACTIVE') {
      throw new BadRequestException('The dam is no longer active on the farm');
    }
    await this.animals.assertParents(workspaceId, dto.sireId, dto.damId);

    const openRecord = await this.prisma.breedingRecord.findFirst({
      where: { workspaceId, damId: dto.damId, status: { in: ['MATED', 'PREGNANT'] } },
    });
    if (openRecord) {
      throw new ConflictException('This dam already has an open breeding record');
    }

    const matingDate = new Date(dto.matingDate);
    const expected = dto.expectedKiddingDate ? new Date(dto.expectedKiddingDate) : expectedKiddingDate(matingDate);
    if (expected <= matingDate) {
      throw new BadRequestException('expectedKiddingDate must be after matingDate');
    }

    return this.prisma.breedingRecord.create({
      data: {
        workspaceId,
        damId: dto.damId,
        sireId: dto.sireId,
        externalSire: dto.externalSire,
        method: dto.method,
        matingDate,
        expectedKiddingDate: expected,
        notes: dto.notes,
      },
      include: { dam: { select: ANIMAL_SUMMARY }, sire: { select: ANIMAL_SUMMARY } },
    });
  }

  async findAll(workspaceId: string, open?: boolean) {
    return this.prisma.breedingRecord.findMany({
      where: { workspaceId, ...(open ? { status: { in: ['MATED', 'PREGNANT'] } } : {}) },
      include: { dam: { select: ANIMAL_SUMMARY }, sire: { select: ANIMAL_SUMMARY } },
      orderBy: { expectedKiddingDate: 'asc' },
    });
  }

  async updateStatus(workspaceId: string, recordId: string, dto: UpdateBreedingStatusDto) {
    const record = await this.requireRecord(workspaceId, recordId);
    if (!canTransition(record.status, dto.status)) {
      throw new BadRequestException(`Cannot change status from ${record.status} to ${dto.status}`);
    }
    return this.prisma.breedingRecord.update({
      where: { id: recordId },
      data: { status: dto.status, notes: dto.notes ?? record.notes },
    });
  }

  /**
   * Closes the breeding record and registers each live kid as a new Animal
   * (dam/sire from the record, BORN_ON_FARM, born on kiddingDate) in one
   * transaction, so a tag clash leaves nothing half-written.
   */
  async recordKidding(workspaceId: string, recordId: string, dto: RecordKiddingDto) {
    const record = await this.requireRecord(workspaceId, recordId);
    if (!canRecordKidding(record.status)) {
      throw new BadRequestException(`Cannot record kidding for a ${record.status} breeding record`);
    }
    if (dto.kids.length > dto.kidsBorn) {
      throw new BadRequestException('More kids registered than were born');
    }
    const kiddingDate = new Date(dto.kiddingDate);
    if (kiddingDate < record.matingDate) {
      throw new BadRequestException('kiddingDate cannot be before matingDate');
    }

    const tags = dto.kids.map((kid) => kid.tagNumber);
    if (new Set(tags).size !== tags.length) {
      throw new BadRequestException('Kid tag numbers must be unique');
    }
    if (tags.length > 0) {
      const clash = await this.prisma.animal.findFirst({ where: { workspaceId, tagNumber: { in: tags } } });
      if (clash) {
        throw new ConflictException(`Tag number ${clash.tagNumber} is already in use`);
      }
    }

    const dam = await this.prisma.animal.findUniqueOrThrow({ where: { id: record.damId } });

    return this.prisma.$transaction(async (tx) => {
      const kids = [];
      for (const kid of dto.kids) {
        kids.push(
          await tx.animal.create({
            data: {
              workspaceId,
              tagNumber: kid.tagNumber,
              name: kid.name,
              sex: kid.sex,
              color: kid.color,
              species: dam.species,
              breed: dam.breed,
              dateOfBirth: kiddingDate,
              acquisition: 'BORN_ON_FARM',
              acquisitionDate: kiddingDate,
              damId: record.damId,
              sireId: record.sireId,
            },
          }),
        );
      }
      const updated = await tx.breedingRecord.update({
        where: { id: recordId },
        data: {
          status: 'KIDDED',
          kiddingDate,
          kidsBorn: dto.kidsBorn,
          kidsAlive: dto.kids.length,
          complications: dto.complications,
        },
      });
      return { breedingRecord: updated, kids };
    });
  }

  private async requireRecord(workspaceId: string, recordId: string) {
    const record = await this.prisma.breedingRecord.findFirst({ where: { id: recordId, workspaceId } });
    if (!record) {
      throw new NotFoundException('Breeding record not found');
    }
    return record;
  }
}
