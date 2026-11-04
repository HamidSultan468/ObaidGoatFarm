import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DeliveryWorkerService } from './delivery-worker.service.js';
import { NotificationRulesService } from './notification-rules.service.js';

/**
 * In-process schedules. A single backend instance is assumed today; the
 * dedupeKey (rules) and delivery claiming (worker) keep both jobs safe if a
 * second instance is ever added.
 */
@Injectable()
export class NotificationsScheduler {
  private readonly logger = new Logger(NotificationsScheduler.name);
  private rulesRunning = false;
  private deliveriesRunning = false;

  constructor(
    private readonly rules: NotificationRulesService,
    private readonly worker: DeliveryWorkerService,
  ) {}

  @Cron(CronExpression.EVERY_10_MINUTES)
  async runRules() {
    if (this.rulesRunning) return;
    this.rulesRunning = true;
    try {
      const created = await this.rules.evaluateAllWorkspaces();
      if (created > 0) this.logger.log(`Notification rules created ${created} notification(s)`);
    } catch (error) {
      this.logger.error(`Notification rules run failed: ${(error as Error).message}`);
    } finally {
      this.rulesRunning = false;
    }
  }

  @Cron(CronExpression.EVERY_MINUTE)
  async runDeliveries() {
    if (this.deliveriesRunning) return;
    this.deliveriesRunning = true;
    try {
      await this.worker.processDue();
    } catch (error) {
      this.logger.error(`Delivery worker failed: ${(error as Error).message}`);
    } finally {
      this.deliveriesRunning = false;
    }
  }
}
