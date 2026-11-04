import { IsIn } from 'class-validator';
import type { GlobalRole } from '@prisma/client';

/** SUPER_ADMIN_OWNER is deliberately excluded — ownership transfer is too sensitive for a plain role-update endpoint. */
const ASSIGNABLE_GLOBAL_ROLES: GlobalRole[] = ['ADMIN', 'USER'];

export class UpdateGlobalRoleDto {
  @IsIn(ASSIGNABLE_GLOBAL_ROLES)
  globalRole!: GlobalRole;
}
