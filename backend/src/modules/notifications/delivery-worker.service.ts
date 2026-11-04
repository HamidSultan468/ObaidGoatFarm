import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MAX_DELIVERY_ATTEMPTS, quietHoursEnd, retryDelayMs } from './delivery-timing.util.js';
import { MailerService } from './mailer.service.js';

const BATCH_SIZE = 50;
/** A claimed delivery is hidden from other workers for this long. */
const CLAIM_MS = 5 * 60_000;

/**
 * Sends queued email deliveries: respects quiet hours, retries with backoff
 * (1/5/15/60 min) up to MAX_DELIVERY_ATTEMPTS, and records every outcome.
 * Each row is claimed with a conditional update first, so two instances
 * never send the same email twice.
 */
@Injectable()
export class DeliveryWorkerService {
  private readonly logger = new Logger(DeliveryWorkerService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly mailer: MailerService,
  ) {}

  async processDue(now = new Date()): Promise<{ sent: number; failed: number; deferred: number; skipped: number }> {
    const due = await this.prisma.notificationDelivery.findMany({
      where: { status: 'PENDING', nextAttemptAt: { lte: now } },
      include: {
        notification: {
          select: {
            title: true,
            body: true,
            user: { select: { email: true, timeZone: true, quietHoursStart: true, quietHoursEnd: true } },
          },
        },
      },
      orderBy: { nextAttemptAt: 'asc' },
      take: BATCH_SIZE,
    });

    const result = { sent: 0, failed: 0, deferred: 0, skipped: 0 };
    for (const delivery of due) {
      const claimed = await this.prisma.notificationDelivery.updateMany({
        where: { id: delivery.id, status: 'PENDING', nextAttemptAt: delivery.nextAttemptAt },
        data: { nextAttemptAt: new Date(now.getTime() + CLAIM_MS) },
      });
      if (claimed.count !== 1) continue;

      if (!this.mailer.isConfigured) {
        await this.prisma.notificationDelivery.update({
          where: { id: delivery.id },
          data: { status: 'SKIPPED', lastError: 'Email is not configured' },
        });
        result.skipped++;
        continue;
      }

      const { user, title, body } = delivery.notification;
      const quietUntil = quietHoursEnd(now, user.timeZone, user.quietHoursStart, user.quietHoursEnd);
      if (quietUntil) {
        await this.prisma.notificationDelivery.update({ where: { id: delivery.id }, data: { nextAttemptAt: quietUntil } });
        result.deferred++;
        continue;
      }

      try {
        await this.mailer.send(user.email, title, body);
        await this.prisma.notificationDelivery.update({
          where: { id: delivery.id },
          data: { status: 'SENT', sentAt: new Date(), attempts: { increment: 1 }, lastError: null },
        });
        result.sent++;
      } catch (error) {
        const attempts = delivery.attempts + 1;
        const giveUp = attempts >= MAX_DELIVERY_ATTEMPTS;
        await this.prisma.notificationDelivery.update({
          where: { id: delivery.id },
          data: {
            attempts,
            status: giveUp ? 'FAILED' : 'PENDING',
            lastError: (error as Error).message.slice(0, 500),
            nextAttemptAt: new Date(now.getTime() + retryDelayMs(attempts)),
          },
        });
        result.failed++;
        this.logger.warn(`Email delivery ${delivery.id} attempt ${attempts} failed: ${(error as Error).message}`);
      }
    }
    return result;
  }
}
