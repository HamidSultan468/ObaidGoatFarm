import { IsIn } from 'class-validator';
import type { WorkspaceRole } from '@prisma/client';

const ASSIGNABLE_ROLES: WorkspaceRole[] = ['ADMIN', 'MANAGER', 'STAFF', 'VIEWER'];

export class UpdateMemberRoleDto {
  /** OWNER is excluded — ownership transfer is a separate, more sensitive operation. */
  @IsIn(ASSIGNABLE_ROLES)
  role!: WorkspaceRole;
}
