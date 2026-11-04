import { Module } from '@nestjs/common';
import { FarmModule } from '../farm/farm.module.js';
import { DeliveryWorkerService } from './delivery-worker.service.js';
import { MailerService } from './mailer.service.js';
import { NotificationRulesService } from './notification-rules.service.js';
import {
  AdminNotificationsController,
  NotificationsController,
  WorkspaceNotificationsController,
} from './notifications.controller.js';
import { NotificationsScheduler } from './notifications.scheduler.js';
import { NotificationsService } from './notifications.service.js';

/** Notification System (Phase 09): in-app inbox, automatic rules, email delivery with retries. */
@Module({
  imports: [FarmModule],
  controllers: [NotificationsController, WorkspaceNotificationsController, AdminNotificationsController],
  providers: [NotificationsService, NotificationRulesService, DeliveryWorkerService, MailerService, NotificationsScheduler],
  // Other modules (backup results, AI drafts) raise event notifications through NotificationsService.
  exports: [NotificationsService],
})
export class NotificationsModule {}
