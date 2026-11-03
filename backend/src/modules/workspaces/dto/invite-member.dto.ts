import { IsEmail, IsIn } from 'class-validator';
import type { WorkspaceRole } from '@prisma/client';

const INVITABLE_ROLES: WorkspaceRole[] = ['ADMIN', 'MANAGER', 'STAFF', 'VIEWER'];

export class InviteMemberDto {
  @IsEmail()
  email!: string;

  /** OWNER is excluded — ownership transfer is a separate, more sensitive operation, not a plain invite. */
  @IsIn(INVITABLE_ROLES)
  role!: WorkspaceRole;
}
