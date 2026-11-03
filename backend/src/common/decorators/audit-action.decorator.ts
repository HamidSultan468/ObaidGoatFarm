import { SetMetadata } from '@nestjs/common';

export const AUDIT_ACTION_KEY = 'auditAction';

/** Gives a route a human-readable audit action name, e.g. @AuditAction('workspace.member.invite'). */
export const AuditAction = (action: string) => SetMetadata(AUDIT_ACTION_KEY, action);
