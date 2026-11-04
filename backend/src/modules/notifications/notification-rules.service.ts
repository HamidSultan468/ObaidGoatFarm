import { Injectable, Logger } from '@nestjs/common';
import type { NotificationCategory } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service.js';
import { FarmOverviewService } from '../farm/overview/farm-overview.service.js';
import { HEALTH_DUE_LEAD_DAYS, KIDDING_LEAD_DAYS, LEASE_LEAD_DAYS } from './notification-rules.config.js';
import { NotificationsService, type NotificationPayload } from './notifications.service.js';

const DAY_MS = 24 * 60 * 60 * 1000;
const isoDay = (date: Date) => date.toISOString().slice(0, 10);
const humanize = (value: string) => value.charAt(0) + value.slice(1).toLowerCase().replace(/_/g, ' ');

/**
 * Automatic reminders. Each rule turns current data into notification
 * candidates with a stable dedupeKey, so running the rules every 15 minutes
 * (or on demand) never repeats a reminder for the same user. New source
 * modules add a method here; delivery, preferences and recipients are shared.
 */
@Injectable()
export class NotificationRulesService {
  private readonly logger = new Logger(NotificationRulesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly farmOverview: FarmOverviewService,
  ) {}

  async evaluateAllWorkspaces(now = new Date()): Promise<number> {
    const workspaces = await this.prisma.workspace.findMany({ where: { isActive: true }, select: { id: true } });
    let total = 0;
    for (const { id } of workspaces) {
      try {
        total += await this.evaluateWorkspace(id, now);
      } catch (error) {
        this.logger.error(`Notification rules failed for workspace ${id}: ${(error as Error).message}`);
      }
    }
    return total;
  }

  /** Returns the number of notifications newly created. */
  async evaluateWorkspace(workspaceId: string, now = new Date()): Promise<number> {
    const candidates: NotificationPayload[] = [
      ...(await this.farmCandidates(workspaceId, now)),
      ...(await this.leaseCandidates(workspaceId, now)),
      ...(await this.approvalCandidates(workspaceId)),
    ];

    const ruleCache = new Map<NotificationCategory, Awaited<ReturnType<NotificationsService['resolveRule']>>>();
    let created = 0;
    for (const candidate of candidates) {
      if (!ruleCache.has(candidate.category)) {
        ruleCache.set(candidate.category, await this.notifications.resolveRule(workspaceId, candidate.category));
      }
      const rule = ruleCache.get(candidate.category)!;
      if (!rule.isEnabled) continue;
      created += await this.notifications.notifyRoles(workspaceId, rule.recipientRoles, candidate);
    }
    return created;
  }

  private async farmCandidates(workspaceId: string, now: Date): Promise<NotificationPayload[]> {
    const overview = await this.farmOverview.getOverview(workspaceId, now);
    const healthHorizon = now.getTime() + HEALTH_DUE_LEAD_DAYS * DAY_MS;
    const kiddingHorizon = now.getTime() + KIDDING_LEAD_DAYS * DAY_MS;
    const out: NotificationPayload[] = [];

    for (const item of overview.dueHealth) {
      if (!item.nextDueDate || item.nextDueDate.getTime() > healthHorizon) continue;
      const animal = item.animal.name ? `${item.animal.tagNumber} (${item.animal.name})` : item.animal.tagNumber;
      out.push({
        category: 'FARM_HEALTH',
        severity: item.overdue ? 'WARNING' : 'INFO',
        title: `${humanize(item.type)} ${item.overdue ? 'overdue' : 'due'}: ${animal}`,
        body: `${item.description} — due ${isoDay(item.nextDueDate)}.`,
        link: `/goat-farm/animals/${item.animal.id}`,
        // Separate keys: a "due soon" reminder, then one escalation if it goes overdue.
        dedupeKey: `health-${item.overdue ? 'overdue' : 'due'}:${item.id}`,
      });
    }

    for (const kidding of overview.upcomingKiddings) {
      if (kidding.expectedKiddingDate.getTime() > kiddingHorizon) continue;
      const overdue = kidding.expectedKiddingDate < now;
      const dam = kidding.dam.name ? `${kidding.dam.tagNumber} (${kidding.dam.name})` : kidding.dam.tagNumber;
      out.push({
        category: 'FARM_BREEDING',
        severity: overdue ? 'WARNING' : 'INFO',
        title: overdue ? `Kidding overdue: ${dam}` : `Kidding expected soon: ${dam}`,
        body: `Expected kidding date ${isoDay(kidding.expectedKiddingDate)}.`,
        link: `/goat-farm/animals/${kidding.dam.id}`,
        dedupeKey: `kidding-${overdue ? 'overdue' : 'soon'}:${kidding.id}`,
      });
    }
    return out;
  }

  private async leaseCandidates(workspaceId: string, now: Date): Promise<NotificationPayload[]> {
    const parcels = await this.prisma.landParcel.findMany({
      where: {
        workspaceId,
        status: 'ACTIVE',
        tenure: { not: 'OWNED' },
        leaseEndDate: { not: null, lte: new Date(now.getTime() + LEASE_LEAD_DAYS * DAY_MS) },
      },
      select: { id: true, name: true, leaseEndDate: true },
    });
    return parcels.map((parcel) => {
      const ended = parcel.leaseEndDate! < now;
      return {
        category: 'LAND_LEASE' as const,
        severity: ended ? ('WARNING' as const) : ('INFO' as const),
        title: ended ? `Lease ended: ${parcel.name}` : `Lease ending soon: ${parcel.name}`,
        body: `Lease end date ${isoDay(parcel.leaseEndDate!)}. Renew it or mark the land "lease ended".`,
        link: `/land/parcels/${parcel.id}`,
        dedupeKey: `lease-${ended ? 'ended' : 'soon'}:${parcel.id}:${isoDay(parcel.leaseEndDate!)}`,
      };
    });
  }

  private async approvalCandidates(workspaceId: string): Promise<NotificationPayload[]> {
    const pending = await this.prisma.journalEntry.findMany({
      where: { workspaceId, status: 'PENDING_APPROVAL' },
      select: { id: true, memo: true, entryType: true, createdAt: true },
    });
    return pending.map((entry) => ({
      category: 'APPROVALS' as const,
      severity: 'WARNING' as const,
      title: 'Transaction awaiting approval',
      body: `${humanize(entry.entryType)}${entry.memo ? `: ${entry.memo}` : ''} needs an owner or admin to approve or reject it.`,
      link: '/accounts',
      dedupeKey: `approval:${entry.id}`,
    }));
  }
}
