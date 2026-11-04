import { createParamDecorator, type ExecutionContext } from '@nestjs/common';
import type { GlobalRole } from '@prisma/client';

export interface AuthenticatedUser {
  userId: string;
  email: string;
  globalRole: GlobalRole;
  mfaEnabled: boolean;
}

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedUser => {
    const request = ctx.switchToHttp().getRequest<{ user: AuthenticatedUser }>();
    return request.user;
  },
);
