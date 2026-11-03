import { SetMetadata } from '@nestjs/common';
import type { WorkspaceRole } from '@prisma/client';

export const ROLES_KEY = 'roles';

/** Declares which WorkspaceRole values may access a route. Checked by RolesGuard. */
export const Roles = (...roles: WorkspaceRole[]) => SetMetadata(ROLES_KEY, roles);
