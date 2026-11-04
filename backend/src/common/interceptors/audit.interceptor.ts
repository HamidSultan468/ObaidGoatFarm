import { Injectable, type CallHandler, type ExecutionContext, type NestInterceptor } from '@nestjs/common';
import type { Request } from 'express';
import { type Observable, tap } from 'rxjs';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../decorators/current-user.decorator.js';
import type { WorkspaceMembershipContext } from '../guards/workspace.guard.js';
import { AUDIT_ACTION_KEY } from '../decorators/audit-action.decorator.js';

const MUTATING_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

/**
 * Writes an AuditLog row for every mutating request on a route, satisfying
 * CLAUDE.md §3/§7 ("maintain complete audit trails" / "audit logging where
 * appropriate"). Failures to write the audit log do not fail the request,
 * but are logged loudly — an audit gap must never go unnoticed.
 */
@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthenticatedUser; membership?: WorkspaceMembershipContext }>();

    const explicitAction = this.reflector.getAllAndOverride<string>(AUDIT_ACTION_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    // Every mutation is audited; reads only when the route opts in with
    // @AuditAction (sensitive reads such as backup downloads and exports).
    if (!MUTATING_METHODS.has(request.method) && !explicitAction) {
      return next.handle();
    }

    const action = explicitAction ?? `${request.method} ${request.route?.path ?? request.url}`;

    return next.handle().pipe(
      tap((result) => {
        this.prisma.auditLog
          .create({
            data: {
              workspaceId: request.membership?.workspaceId,
              userId: request.user?.userId,
              action,
              entityType: context.getClass().name,
              entityId: this.extractEntityId(result),
              ipAddress: request.ip,
            },
          })
          .catch((error: unknown) => {
            // eslint-disable-next-line no-console
            console.error(`AUDIT LOG WRITE FAILED for action "${action}":`, error);
          });
      }),
    );
  }

  private extractEntityId(result: unknown): string | undefined {
    if (result && typeof result === 'object' && 'id' in result) {
      const id = (result as { id: unknown }).id;
      return typeof id === 'string' ? id : undefined;
    }
    return undefined;
  }
}
