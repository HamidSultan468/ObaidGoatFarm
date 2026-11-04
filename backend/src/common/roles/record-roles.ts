import type { WorkspaceRole } from '@prisma/client';

/** Day-to-day data entry (ROLES_PERMISSIONS.md: STAFF = data entry). */
export const RECORD_WRITERS: WorkspaceRole[] = ['OWNER', 'ADMIN', 'MANAGER', 'STAFF'];

/** One-way or destructive actions: exits, deletions. */
export const RECORD_MANAGERS: WorkspaceRole[] = ['OWNER', 'ADMIN', 'MANAGER'];

/** Financial reports (P&L, balance sheet, trial balance, cash, land money). */
export const FINANCE_VIEWERS: WorkspaceRole[] = ['OWNER', 'ADMIN', 'MANAGER'];

/** Farm operations reports (herd, kidding, health, growth). */
export const FARM_REPORT_VIEWERS: WorkspaceRole[] = ['OWNER', 'ADMIN', 'MANAGER', 'STAFF'];

/** Audit log and operations reports. */
export const AUDIT_VIEWERS: WorkspaceRole[] = ['OWNER', 'ADMIN'];
