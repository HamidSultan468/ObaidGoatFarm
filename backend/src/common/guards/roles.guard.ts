import { ForbiddenException, Injectable, type CanActivate, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import type { WorkspaceRole } from '@prisma/client';
import { ROLES_KEY } from '../decorators/roles.decorator.js';
import type { WorkspaceMembershipContext } from './workspace.guard.js';

/** Must run after WorkspaceGuard, which populates request.membership. */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<WorkspaceRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const request = context
      .switchToHttp()
      .getRequest<Request & { membership?: WorkspaceMembershipContext }>();

    if (!request.membership || !requiredRoles.includes(request.membership.role)) {
      throw new ForbiddenException('Your role does not permit this action');
    }

    return true;
  }
}
