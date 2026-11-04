import { ForbiddenException, Injectable, type CanActivate, type ExecutionContext } from '@nestjs/common';
import type { AuthenticatedUser } from '../decorators/current-user.decorator.js';

/**
 * Enforces CLAUDE.md §3's "protect critical owner operations with MFA":
 * the caller's account must have MFA enabled to reach the route at all.
 * Apply to Super Admin Owner mutations alongside GlobalRolesGuard.
 */
@Injectable()
export class MfaRequiredGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{ user: AuthenticatedUser }>();
    if (!request.user.mfaEnabled) {
      throw new ForbiddenException('This action requires multi-factor authentication to be enabled on your account');
    }
    return true;
  }
}
