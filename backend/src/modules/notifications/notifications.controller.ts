import { Body, Controller, Get, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../common/decorators/current-user.decorator.js';
import { GlobalRoles } from '../../common/decorators/global-roles.decorator.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { GlobalRolesGuard } from '../../common/guards/global-roles.guard.js';
import { MfaRequiredGuard } from '../../common/guards/mfa-required.guard.js';
import { RolesGuard } from '../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../common/guards/workspace.guard.js';
import { DeliveryWorkerService } from './delivery-worker.service.js';
import {
  ListNotificationsQueryDto,
  SendPlatformAnnouncementDto,
  SendWorkspaceNotificationDto,
  UpdatePreferencesDto,
  UpdateRulesDto,
} from './dto/notifications.dto.js';
import { NotificationRulesService } from './notification-rules.service.js';
import { NotificationsService } from './notifications.service.js';

/** The signed-in user's own inbox and preferences. Never exposes other users' rows. */
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@CurrentUser() user: AuthenticatedUser, @Query() query: ListNotificationsQueryDto) {
    const limit = query.limit ? Number.parseInt(query.limit, 10) : undefined;
    return this.notifications.list(user.userId, {
      unreadOnly: query.unread === 'true',
      limit: Number.isNaN(limit) ? undefined : limit,
      workspaceId: query.workspaceId,
    });
  }

  @Get('unread-count')
  unreadCount(@CurrentUser() user: AuthenticatedUser, @Query('workspaceId') workspaceId?: string) {
    return this.notifications.unreadCount(user.userId, workspaceId);
  }

  @Post('read-all')
  markAllRead(@CurrentUser() user: AuthenticatedUser, @Query('workspaceId') workspaceId?: string) {
    return this.notifications.markAllRead(user.userId, workspaceId);
  }

  @Get('preferences')
  getPreferences(@CurrentUser() user: AuthenticatedUser) {
    return this.notifications.getPreferences(user.userId);
  }

  @Put('preferences')
  @AuditAction('notifications.preferences.update')
  updatePreferences(@CurrentUser() user: AuthenticatedUser, @Body() dto: UpdatePreferencesDto) {
    return this.notifications.updatePreferences(user.userId, dto);
  }

  @Post(':notificationId/read')
  markRead(@CurrentUser() user: AuthenticatedUser, @Param('notificationId') notificationId: string) {
    return this.notifications.markRead(user.userId, notificationId);
  }
}

/** Workspace owner/admin controls: rules, manual sending, delivery log. */
@Controller('workspaces/:workspaceId')
@UseGuards(WorkspaceGuard, RolesGuard)
@Roles('OWNER', 'ADMIN')
export class WorkspaceNotificationsController {
  constructor(
    private readonly notifications: NotificationsService,
    private readonly rules: NotificationRulesService,
    private readonly worker: DeliveryWorkerService,
  ) {}

  @Get('notification-rules')
  getRules(@Param('workspaceId') workspaceId: string) {
    return this.notifications.getRules(workspaceId);
  }

  @Put('notification-rules')
  @AuditAction('notifications.rules.update')
  updateRules(@Param('workspaceId') workspaceId: string, @Body() dto: UpdateRulesDto) {
    return this.notifications.updateRules(workspaceId, dto.rules);
  }

  /** Evaluate the automatic rules now instead of waiting for the 10-minute schedule. */
  @Post('notification-rules/run')
  @AuditAction('notifications.rules.run')
  async runRules(@Param('workspaceId') workspaceId: string) {
    const created = await this.rules.evaluateWorkspace(workspaceId);
    const deliveries = await this.worker.processDue();
    return { created, deliveries };
  }

  @Post('notifications/send')
  @AuditAction('notifications.workspace.send')
  send(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: SendWorkspaceNotificationDto,
  ) {
    return this.notifications.sendToWorkspace(workspaceId, user.userId, dto);
  }

  @Get('notifications/deliveries')
  deliveries(@Param('workspaceId') workspaceId: string) {
    return this.notifications.listDeliveries(workspaceId);
  }
}

/** Super Admin Owner: platform announcements (MFA required, like every owner mutation). */
@Controller('admin/notifications')
@UseGuards(GlobalRolesGuard, MfaRequiredGuard)
@GlobalRoles('SUPER_ADMIN_OWNER')
export class AdminNotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Post('send')
  @AuditAction('admin.notifications.send')
  send(@CurrentUser() user: AuthenticatedUser, @Body() dto: SendPlatformAnnouncementDto) {
    return this.notifications.sendPlatformAnnouncement(user.userId, dto);
  }
}
