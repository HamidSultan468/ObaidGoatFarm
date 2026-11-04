import { SetMetadata } from '@nestjs/common';
import type { GlobalRole } from '@prisma/client';

export const GLOBAL_ROLES_KEY = 'globalRoles';

/** Declares which platform-level GlobalRole values may access a route (Super Admin console). Checked by GlobalRolesGuard. */
export const GlobalRoles = (...roles: GlobalRole[]) => SetMetadata(GLOBAL_ROLES_KEY, roles);
