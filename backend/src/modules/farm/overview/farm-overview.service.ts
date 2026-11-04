import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service.js';

const SCHEDULE_WINDOW_DAYS = 30;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

@Injectable()
export class FarmOverviewService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Herd counts plus the upcoming schedule: health follow-ups due within 30
   * days (overdue ones included) and expected kiddings. Only ACTIVE animals'
   * follow-ups count. A follow-up is "done" once a later record of the same
   * type exists for that animal, so it drops off the list.
   */
  async getOverview(workspaceId: string, now = new Date()) {
    const horizon = new Date(now.getTime() + SCHEDULE_WINDOW_DAYS * MS_PER_DAY);

    const [bySex, byHealth, pregnant, dueRecords, upcomingKiddings] = await Promise.all([
      this.prisma.animal.groupBy({ by: ['sex'], where: { workspaceId, status: 'ACTIVE' }, _count: true }),
      this.prisma.animal.groupBy({ by: ['healthStatus'], where: { workspaceId, status: 'ACTIVE' }, _count: true }),
      this.prisma.breedingRecord.count({ where: { workspaceId, status: 'PREGNANT' } }),
      this.prisma.animalHealthRecord.findMany({
        where: { workspaceId, nextDueDate: { lte: horizon }, animal: { status: 'ACTIVE' } },
        include: { animal: { select: { id: true, tagNumber: true, name: true } } },
        orderBy: { nextDueDate: 'asc' },
      }),
      this.prisma.breedingRecord.findMany({
        where: { workspaceId, status: { in: ['MATED', 'PREGNANT'] }, expectedKiddingDate: { lte: horizon } },
        include: { dam: { select: { id: true, tagNumber: true, name: true } } },
        orderBy: { expectedKiddingDate: 'asc' },
      }),
    ]);

    const latestByAnimalAndType = await this.prisma.animalHealthRecord.groupBy({
      by: ['animalId', 'type'],
      where: { workspaceId, animalId: { in: [...new Set(dueRecords.map((r) => r.animalId))] } },
      _max: { recordDate: true },
    });
    const latestKey = (animalId: string, type: string) => `${animalId}:${type}`;
    const latest = new Map(latestByAnimalAndType.map((row) => [latestKey(row.animalId, row.type), row._max.recordDate]));

    const dueHealth = dueRecords
      .filter((record) => {
        const newest = latest.get(latestKey(record.animalId, record.type));
        return !newest || newest.getTime() <= record.recordDate.getTime();
      })
      .map((record) => ({
        id: record.id,
        type: record.type,
        description: record.description,
        nextDueDate: record.nextDueDate,
        overdue: record.nextDueDate !== null && record.nextDueDate < now,
        animal: record.animal,
      }));

    const count = (rows: Array<{ _count: number }>) => rows.reduce((sum, row) => sum + row._count, 0);
    const sexCount = (sex: string) => bySex.find((row) => row.sex === sex)?._count ?? 0;
    const healthCount = (status: string) => byHealth.find((row) => row.healthStatus === status)?._count ?? 0;

    return {
      activeAnimals: count(bySex),
      males: sexCount('MALE'),
      females: sexCount('FEMALE'),
      healthy: healthCount('HEALTHY'),
      needsAttention: healthCount('SICK') + healthCount('UNDER_TREATMENT') + healthCount('QUARANTINED'),
      pregnant,
      dueHealth,
      upcomingKiddings: upcomingKiddings.map((record) => ({
        id: record.id,
        status: record.status,
        expectedKiddingDate: record.expectedKiddingDate,
        dam: record.dam,
      })),
    };
  }
}
