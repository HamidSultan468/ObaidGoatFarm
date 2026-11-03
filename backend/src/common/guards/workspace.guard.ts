import {
  ForbiddenException,
  Injectable,
  type CanActivate,
  type ExecutionContext,
} from '@nestjs/common';
import type { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../decorators/current-user.decorator.js';
import type { WorkspaceRole } from '@prisma/client';

export interface WorkspaceMembershipContext {
  workspaceId: string;
  role: WorkspaceRole;
}

/**
 * Enforces tenant isolation (CLAUDE.md §4, DECISIONS.md D005): resolves the
 * caller's membership for the :workspaceId in the route and rejects the
 * request if none exists. Never trusts a client-supplied workspace claim —
 * membership is re-checked against the database on every request.
 */
@Injectable()
export class WorkspaceGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context
      .switchToHttp()
      .getRequest<Request & { user: AuthenticatedUser; membership?: WorkspaceMembershipContext }>();

    const workspaceId = request.params.workspaceId;
    if (!workspaceId || Array.isArray(workspaceId)) {
      throw new ForbiddenException('No workspace specified for this request');
    }

    const membership = await this.prisma.workspaceMembership.findUnique({
      where: { userId_workspaceId: { userId: request.user.userId, workspaceId } },
    });

    if (!membership || !membership.isActive) {
      throw new ForbiddenException('You do not have access to this workspace');
    }

    request.membership = { workspaceId, role: membership.role };
    return true;
  }
}
