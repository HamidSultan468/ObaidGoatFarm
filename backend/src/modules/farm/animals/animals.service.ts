import { BadRequestException, ConflictException, Injectable, NotFoundException, PreconditionFailedException } from '@nestjs/common';
import { versionMatches } from '../../../common/idempotency/idempotency.util.js';
import { Prisma, type AnimalSex } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service.js';
import { computeProfitability } from '../../accounting/reports/tagged-profitability.util.js';
import type { CreateAnimalDto, ListAnimalsQueryDto, RecordExitDto, UpdateAnimalDto } from './dto/animal.dto.js';
import type { CreateHealthRecordDto, CreateWeightRecordDto } from './dto/records.dto.js';

const PARENT_SELECT = { id: true, tagNumber: true, name: true } as const;

const toDate = (value?: string) => (value ? new Date(value) : undefined);

@Injectable()
export class AnimalsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(workspaceId: string, dto: CreateAnimalDto) {
    await this.assertParents(workspaceId, dto.sireId, dto.damId);
    try {
      return await this.prisma.animal.create({
        data: {
          workspaceId,
          tagNumber: dto.tagNumber,
          name: dto.name,
          species: dto.species ?? 'GOAT',
          breed: dto.breed,
          sex: dto.sex,
          dateOfBirth: toDate(dto.dateOfBirth),
          color: dto.color,
          healthStatus: dto.healthStatus,
          acquisition: dto.acquisition,
          acquisitionDate: toDate(dto.acquisitionDate),
          ownership: dto.ownership,
          sireId: dto.sireId,
          damId: dto.damId,
          dietaryRestrictions: dto.dietaryRestrictions,
          notes: dto.notes,
        },
      });
    } catch (error) {
      throw this.mapUniqueTagError(error);
    }
  }

  async findAll(workspaceId: string, query: ListAnimalsQueryDto) {
    const status = query.status ?? 'ACTIVE';
    const search = query.search?.trim();
    return this.prisma.animal.findMany({
      where: {
        workspaceId,
        ...(status === 'ALL' ? {} : { status }),
        ...(search
          ? {
              OR: [
                { tagNumber: { contains: search, mode: 'insensitive' } },
                { name: { contains: search, mode: 'insensitive' } },
                { breed: { contains: search, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      include: {
        weightRecords: { orderBy: { recordDate: 'desc' }, take: 1 },
      },
      orderBy: { tagNumber: 'asc' },
    });
  }

  async findOne(workspaceId: string, animalId: string) {
    const animal = await this.prisma.animal.findFirst({
      where: { id: animalId, workspaceId },
      include: {
        sire: { select: PARENT_SELECT },
        dam: { select: PARENT_SELECT },
        sireOf: { select: { ...PARENT_SELECT, sex: true, dateOfBirth: true, status: true } },
        damOf: { select: { ...PARENT_SELECT, sex: true, dateOfBirth: true, status: true } },
        weightRecords: { orderBy: { recordDate: 'desc' }, take: 1 },
      },
    });
    if (!animal) {
      throw new NotFoundException('Animal not found');
    }
    const { sireOf, damOf, ...rest } = animal;
    return { ...rest, offspring: [...damOf, ...sireOf] };
  }

  /** `ifMatch` = the `updatedAt` the client edited from; a newer version on the server -> 412, nothing changed. */
  async update(workspaceId: string, animalId: string, dto: UpdateAnimalDto, ifMatch?: string) {
    const current = await this.requireAnimal(workspaceId, animalId);
    if (!versionMatches(ifMatch, current.updatedAt)) {
      throw new PreconditionFailedException('This animal was changed by someone else since you opened it. Reload it and apply your change again.');
    }
    if (dto.sireId === animalId || dto.damId === animalId) {
      throw new BadRequestException('An animal cannot be its own parent');
    }
    await this.assertParents(workspaceId, dto.sireId, dto.damId);
    try {
      return await this.prisma.animal.update({
        where: { id: animalId },
        data: {
          ...dto,
          dateOfBirth: toDate(dto.dateOfBirth),
          acquisitionDate: toDate(dto.acquisitionDate),
        },
      });
    } catch (error) {
      throw this.mapUniqueTagError(error);
    }
  }

  /** Sold/deceased is a one-way lifecycle step; history is kept, nothing is deleted. */
  async recordExit(workspaceId: string, animalId: string, dto: RecordExitDto) {
    const animal = await this.requireAnimal(workspaceId, animalId);
    if (animal.status !== 'ACTIVE') {
      throw new BadRequestException(`This animal is already marked ${animal.status}`);
    }
    return this.prisma.animal.update({
      where: { id: animalId },
      data: { status: dto.status, exitDate: new Date(dto.exitDate), exitReason: dto.exitReason },
    });
  }

  async listHealthRecords(workspaceId: string, animalId: string) {
    await this.requireAnimal(workspaceId, animalId);
    return this.prisma.animalHealthRecord.findMany({
      where: { animalId, workspaceId },
      orderBy: { recordDate: 'desc' },
    });
  }

  async addHealthRecord(workspaceId: string, animalId: string, userId: string, dto: CreateHealthRecordDto) {
    await this.requireAnimal(workspaceId, animalId);
    const recordDate = new Date(dto.recordDate);
    const nextDueDate = toDate(dto.nextDueDate);
    if (nextDueDate && nextDueDate < recordDate) {
      throw new BadRequestException('nextDueDate cannot be before recordDate');
    }
    return this.prisma.animalHealthRecord.create({
      data: {
        workspaceId,
        animalId,
        type: dto.type,
        recordDate,
        description: dto.description,
        medication: dto.medication,
        dosage: dto.dosage,
        veterinarian: dto.veterinarian,
        nextDueDate,
        createdByUserId: userId,
      },
    });
  }

  async deleteHealthRecord(workspaceId: string, animalId: string, recordId: string) {
    const record = await this.prisma.animalHealthRecord.findFirst({ where: { id: recordId, animalId, workspaceId } });
    if (!record) {
      throw new NotFoundException('Health record not found');
    }
    await this.prisma.animalHealthRecord.delete({ where: { id: recordId } });
    return { deleted: true };
  }

  async listWeights(workspaceId: string, animalId: string) {
    await this.requireAnimal(workspaceId, animalId);
    return this.prisma.animalWeightRecord.findMany({
      where: { animalId, workspaceId },
      orderBy: { recordDate: 'asc' },
    });
  }

  async addWeight(workspaceId: string, animalId: string, dto: CreateWeightRecordDto) {
    await this.requireAnimal(workspaceId, animalId);
    if (/^0+(\.0+)?$/.test(dto.weightKg)) {
      throw new BadRequestException('weightKg must be greater than zero');
    }
    return this.prisma.animalWeightRecord.create({
      data: { workspaceId, animalId, recordDate: new Date(dto.recordDate), weightKg: dto.weightKg, notes: dto.notes },
    });
  }

  /** Every POSTED entry tagged with this animal, plus income/expense/net. */
  async getLedger(workspaceId: string, animalId: string) {
    await this.requireAnimal(workspaceId, animalId);
    const entries = await this.prisma.journalEntry.findMany({
      where: { workspaceId, animalId, status: 'POSTED' },
      include: { lines: { include: { account: true } } },
      orderBy: { postedAt: 'desc' },
    });
    return { entries, ...computeProfitability(entries) };
  }

  async requireAnimal(workspaceId: string, animalId: string) {
    const animal = await this.prisma.animal.findFirst({ where: { id: animalId, workspaceId } });
    if (!animal) {
      throw new NotFoundException('Animal not found');
    }
    return animal;
  }

  /** Sire must be a male and dam a female in the same workspace. */
  async assertParents(workspaceId: string, sireId?: string, damId?: string) {
    await this.assertParent(workspaceId, sireId, 'MALE', 'sire');
    await this.assertParent(workspaceId, damId, 'FEMALE', 'dam');
  }

  private async assertParent(workspaceId: string, parentId: string | undefined, sex: AnimalSex, label: string) {
    if (!parentId) return;
    const parent = await this.prisma.animal.findFirst({ where: { id: parentId, workspaceId } });
    if (!parent) {
      throw new BadRequestException(`Invalid ${label}`);
    }
    if (parent.sex !== sex) {
      throw new BadRequestException(`The ${label} must be ${sex.toLowerCase()}`);
    }
  }

  private mapUniqueTagError(error: unknown): unknown {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return new ConflictException('An animal with this tag number already exists');
    }
    return error;
  }
}
