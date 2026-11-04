import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service.js';
import { IDEMPOTENCY_TTL_MS } from './idempotency.util.js';

/** Removes stored idempotent responses older than the retry window (daily). */
@Injectable()
export class IdempotencyCleanupService {
  private readonly logger = new Logger(IdempotencyCleanupService.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async purgeExpired() {
    const { count } = await this.prisma.idempotencyRecord.deleteMany({ where: { createdAt: { lt: new Date(Date.now() - IDEMPOTENCY_TTL_MS) } } });
    if (count > 0) this.logger.log(`Removed ${count} expired idempotency record(s)`);
  }
}
