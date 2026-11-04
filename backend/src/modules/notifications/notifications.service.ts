import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  type NotificationCategory,
  type NotificationSeverity,
  type WorkspaceRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isValidTimeZone } from './delivery-timing.util.js';
import { MailerService } from './mailer.service.js';
import { CATEGORY_DEFAULTS } from './notification-rules.config.js';

export interface NotificationPayload {
  workspaceId?: string | null;
  category: NotificationCategory;
  severity?: NotificationSeverity;
  title: string;
  body: string;
  link?: string;
  /** Same key + same user = created only once (rule reminders). */
  dedupeKey?: string;
  createdByUserId?: string;
}

const CATEGORIES = Object.keys(CATEGORY_DEFAULTS) as NotificationCategory[];

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mailer: MailerService,
  ) {}

  /**
   * Creates one notification per recipient, honoring each user's channel
   * preferences. In-app off + email on = stored as already read (history
   * only) with an email delivery queued. Both off = nothing is created.
   * Returns how many notifications were newly created.
   */
  async notifyUsers(userIds: string[], payload: NotificationPayload): Promise<number> {
    const unique = [...new Set(userIds)];
    if (unique.length === 0) return 0;
    const preferences = await this.prisma.notificationPreference.findMany({
      where: { userId: { in: unique }, category: payload.category },
    });
    const prefOf = new Map(preferences.map((p) => [p.userId, p]));

    let created = 0;
    for (const userId of unique) {
      const pref = prefOf.get(userId);
      const inApp = pref?.inApp ?? true;
      const email = (pref?.email ?? false) && this.mailer.isConfigured;
      // Announcements always reach the inbox: a user can't opt out of them.
      if (!inApp && !email && payload.category !== 'ANNOUNCEMENT') continue;
      try {
        await this.prisma.notification.create({
          data: {
            userId,
            workspaceId: payload.workspaceId ?? null,
            category: payload.category,
            severity: payload.severity ?? 'INFO',
            title: payload.title,
            body: payload.body,
            link: payload.link,
            dedupeKey: payload.dedupeKey,
            createdByUserId: payload.createdByUserId,
            readAt: inApp || payload.category === 'ANNOUNCEMENT' ? null : new Date(),
            deliveries: email ? { create: [{ channel: 'EMAIL' }] } : undefined,
          },
        });
        created++;
      } catch (error) {
        // Unique (userId, dedupeKey): this reminder was already sent.
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') continue;
        throw error;
      }
    }
    return created;
  }

  /** Active members of the workspace holding any of `roles`. */
  async notifyRoles(workspaceId: string, roles: WorkspaceRole[], payload: NotificationPayload): Promise<number> {
    if (roles.length === 0) return 0;
    const members = await this.prisma.workspaceMembership.findMany({
      where: { workspaceId, role: { in: roles }, isActive: true, user: { isActive: true } },
      select: { userId: true },
    });
    return this.notifyUsers(
      members.map((m) => m.userId),
      { ...payload, workspaceId },
    );
  }

  // --- Inbox (always scoped to the requesting user) -------------------------

  async list(userId: string, options: { unreadOnly?: boolean; limit?: number; workspaceId?: string }) {
    return this.prisma.notification.findMany({
      where: {
        userId,
        ...(options.unreadOnly ? { readAt: null } : {}),
        // A workspace's notifications plus platform-wide ones.
        ...(options.workspaceId ? { OR: [{ workspaceId: options.workspaceId }, { workspaceId: null }] } : {}),
      },
      select: {
        id: true,
        workspaceId: true,
        category: true,
        severity: true,
        title: true,
        body: true,
        link: true,
        readAt: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(options.limit ?? 50, 1), 200),
    });
  }

  async unreadCount(userId: string, workspaceId?: string) {
    const count = await this.prisma.notification.count({
      where: {
        userId,
        readAt: null,
        ...(workspaceId ? { OR: [{ workspaceId }, { workspaceId: null }] } : {}),
      },
    });
    return { count };
  }

  async markRead(userId: string, notificationId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { readAt: new Date() },
    });
    if (result.count === 0) throw new NotFoundException('Notification not found');
    return { read: true };
  }

  async markAllRead(userId: string, workspaceId?: string) {
    const result = await this.prisma.notification.updateMany({
      where: { userId, readAt: null, ...(workspaceId ? { OR: [{ workspaceId }, { workspaceId: null }] } : {}) },
      data: { readAt: new Date() },
    });
    return { updated: result.count };
  }

  // --- Preferences ----------------------------------------------------------

  async getPreferences(userId: string) {
    const [user, rows] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({
        where: { id: userId },
        select: { timeZone: true, quietHoursStart: true, quietHoursEnd: true },
      }),
      this.prisma.notificationPreference.findMany({ where: { userId } }),
    ]);
    const byCategory = new Map(rows.map((r) => [r.category, r]));
    return {
      channels: { inApp: true, email: this.mailer.isConfigured },
      timeZone: user.timeZone,
      quietHoursStart: user.quietHoursStart,
      quietHoursEnd: user.quietHoursEnd,
      categories: CATEGORIES.map((category) => ({
        category,
        inApp: byCategory.get(category)?.inApp ?? true,
        email: byCategory.get(category)?.email ?? false,
      })),
    };
  }

  async updatePreferences(
    userId: string,
    dto: {
      timeZone?: string;
      quietHoursStart?: number | null;
      quietHoursEnd?: number | null;
      categories?: Array<{ category: NotificationCategory; inApp: boolean; email: boolean }>;
    },
  ) {
    if (dto.timeZone && !isValidTimeZone(dto.timeZone)) {
      throw new BadRequestException('Unknown time zone');
    }
    if ((dto.quietHoursStart === null) !== (dto.quietHoursEnd === null)) {
      throw new BadRequestException('Set both quiet-hours times, or clear both');
    }
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: {
          ...(dto.timeZone ? { timeZone: dto.timeZone } : {}),
          ...(dto.quietHoursStart !== undefined ? { quietHoursStart: dto.quietHoursStart } : {}),
          ...(dto.quietHoursEnd !== undefined ? { quietHoursEnd: dto.quietHoursEnd } : {}),
        },
      }),
      ...(dto.categories ?? []).map((c) =>
        this.prisma.notificationPreference.upsert({
          where: { userId_category: { userId, category: c.category } },
          create: { userId, category: c.category, inApp: c.inApp, email: c.email },
          update: { inApp: c.inApp, email: c.email },
        }),
      ),
    ]);
    return this.getPreferences(userId);
  }

  // --- Workspace rules (owner-configurable recipients) ----------------------

  async getRules(workspaceId: string) {
    const rows = await this.prisma.workspaceNotificationRule.findMany({ where: { workspaceId } });
    const byCategory = new Map(rows.map((r) => [r.category, r]));
    return CATEGORIES.filter((c) => CATEGORY_DEFAULTS[c].automatic).map((category) => ({
      category,
      isEnabled: byCategory.get(category)?.isEnabled ?? true,
      recipientRoles: byCategory.get(category)?.recipientRoles ?? CATEGORY_DEFAULTS[category].defaultRoles,
    }));
  }

  async updateRules(
    workspaceId: string,
    rules: Array<{ category: NotificationCategory; isEnabled: boolean; recipientRoles: WorkspaceRole[] }>,
  ) {
    for (const rule of rules) {
      if (!CATEGORY_DEFAULTS[rule.category].automatic) {
        throw new BadRequestException(`${rule.category} is not an automatic rule`);
      }
    }
    await this.prisma.$transaction(
      rules.map((rule) =>
        this.prisma.workspaceNotificationRule.upsert({
          where: { workspaceId_category: { workspaceId, category: rule.category } },
          create: { workspaceId, ...rule, recipientRoles: [...new Set(rule.recipientRoles)] },
          update: { isEnabled: rule.isEnabled, recipientRoles: [...new Set(rule.recipientRoles)] },
        }),
      ),
    );
    return this.getRules(workspaceId);
  }

  /** The configured rule for one category (defaults when no row exists). */
  async resolveRule(workspaceId: string, category: NotificationCategory) {
    const row = await this.prisma.workspaceNotificationRule.findUnique({
      where: { workspaceId_category: { workspaceId, category } },
    });
    return {
      isEnabled: row?.isEnabled ?? true,
      recipientRoles: row?.recipientRoles ?? CATEGORY_DEFAULTS[category].defaultRoles,
    };
  }

  /** Event-driven notifications from other modules (backup result, new drafts). */
  async notifyByRule(workspaceId: string, payload: NotificationPayload): Promise<number> {
    const rule = await this.resolveRule(workspaceId, payload.category);
    if (!rule.isEnabled) return 0;
    return this.notifyRoles(workspaceId, rule.recipientRoles, payload);
  }

  // --- Manual sending -------------------------------------------------------

  async sendToWorkspace(
    workspaceId: string,
    senderId: string,
    dto: { title: string; body: string; severity?: NotificationSeverity; roles?: WorkspaceRole[]; userIds?: string[] },
  ) {
    if (!dto.roles?.length && !dto.userIds?.length) {
      throw new BadRequestException('Choose at least one role or member');
    }
    const members = await this.prisma.workspaceMembership.findMany({
      where: {
        workspaceId,
        isActive: true,
        OR: [...(dto.roles?.length ? [{ role: { in: dto.roles } }] : []), ...(dto.userIds?.length ? [{ userId: { in: dto.userIds } }] : [])],
      },
      select: { userId: true },
    });
    if (dto.userIds?.length) {
      const memberIds = new Set(members.map((m) => m.userId));
      if (dto.userIds.some((id) => !memberIds.has(id))) {
        throw new BadRequestException('Every recipient must be an active member of this workspace');
      }
    }
    const sent = await this.notifyUsers(
      members.map((m) => m.userId),
      { workspaceId, category: 'ANNOUNCEMENT', severity: dto.severity, title: dto.title, body: dto.body, createdByUserId: senderId },
    );
    return { recipients: sent };
  }

  /** Super Admin Owner: platform-wide or to selected users. */
  async sendPlatformAnnouncement(
    senderId: string,
    dto: { title: string; body: string; severity?: NotificationSeverity; userIds?: string[] },
  ) {
    const users = await this.prisma.user.findMany({
      where: { isActive: true, ...(dto.userIds?.length ? { id: { in: dto.userIds } } : {}) },
      select: { id: true },
    });
    if (dto.userIds?.length && users.length !== new Set(dto.userIds).size) {
      throw new BadRequestException('One or more users do not exist or are inactive');
    }
    const sent = await this.notifyUsers(
      users.map((u) => u.id),
      { workspaceId: null, category: 'ANNOUNCEMENT', severity: dto.severity, title: dto.title, body: dto.body, createdByUserId: senderId },
    );
    return { recipients: sent };
  }

  /** Delivery log for a workspace's notifications (owner/admin). */
  async listDeliveries(workspaceId: string) {
    return this.prisma.notificationDelivery.findMany({
      where: { notification: { workspaceId } },
      select: {
        id: true,
        channel: true,
        status: true,
        attempts: true,
        lastError: true,
        nextAttemptAt: true,
        sentAt: true,
        createdAt: true,
        notification: { select: { title: true, category: true, user: { select: { email: true } } } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }
}
