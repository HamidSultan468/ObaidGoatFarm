import type { NotificationCategory, WorkspaceRole } from '@prisma/client';

export interface CategoryDefaults {
  /** Can owners turn this into an automatic rule (vs. event/manual only)? */
  automatic: boolean;
  defaultRoles: WorkspaceRole[];
}

/**
 * Built-in defaults, used when a workspace has no WorkspaceNotificationRule
 * row for a category. Owners/admins can override enabled + recipient roles.
 */
export const CATEGORY_DEFAULTS: Record<NotificationCategory, CategoryDefaults> = {
  FARM_HEALTH: { automatic: true, defaultRoles: ['OWNER', 'ADMIN', 'MANAGER', 'STAFF'] },
  FARM_BREEDING: { automatic: true, defaultRoles: ['OWNER', 'ADMIN', 'MANAGER', 'STAFF'] },
  LAND_LEASE: { automatic: true, defaultRoles: ['OWNER', 'ADMIN', 'MANAGER'] },
  APPROVALS: { automatic: true, defaultRoles: ['OWNER', 'ADMIN'] },
  DRAFTS: { automatic: true, defaultRoles: ['OWNER', 'ADMIN', 'MANAGER'] },
  BACKUP: { automatic: true, defaultRoles: ['OWNER', 'ADMIN'] },
  ANNOUNCEMENT: { automatic: false, defaultRoles: [] },
};

/** Look-ahead windows for the automatic rules. */
export const HEALTH_DUE_LEAD_DAYS = 3;
export const KIDDING_LEAD_DAYS = 7;
export const LEASE_LEAD_DAYS = 30;
