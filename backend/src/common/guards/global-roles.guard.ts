import { ForbiddenException, Injectable, type CanActivate, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { GlobalRole } from '@prisma/client';
import { GLOBAL_ROLES_KEY } from '../decorators/global-roles.decorator.js';
import type { AuthenticatedUser } from '../decorators/current-user.decorator.js';

/** Gates platform-level (Super Admin console) routes by GlobalRole — distinct from RolesGuard, which gates per-workspace WorkspaceRole. */
@Injectable()
export class GlobalRolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<GlobalRole[]>(GLOBAL_ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<{ user: AuthenticatedUser }>();
    if (!requiredRoles.includes(request.user.globalRole)) {
      throw new ForbiddenException('You do not have permission to perform this action');
    }

    return true;
  }
}
