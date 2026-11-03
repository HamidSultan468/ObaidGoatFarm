import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import configuration from './config/configuration.js';
import { validateEnv } from './config/env.validation.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { AuthModule } from './modules/auth/auth.module.js';
import { HealthModule } from './modules/health/health.module.js';
import { WorkspacesModule } from './modules/workspaces/workspaces.module.js';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard.js';
import { AuditInterceptor } from './common/interceptors/audit.interceptor.js';
import { HttpExceptionFilter } from './common/filters/http-exception.filter.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validate: validateEnv,
    }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),
    PrismaModule,
    AuthModule,
    HealthModule,
    WorkspacesModule,
  ],
  providers: [
    // Order matters: throttle -> authenticate.
    //
    // RolesGuard is deliberately NOT global: it reads request.membership,
    // which only WorkspaceGuard populates, and WorkspaceGuard itself is
    // route-level (it needs a :workspaceId param that not every route has).
    // A global RolesGuard would run before a route-level WorkspaceGuard and
    // reject every role-gated request before membership is ever resolved.
    // Routes that need role checks apply both together explicitly:
    // @UseGuards(WorkspaceGuard, RolesGuard) + @Roles(...).
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_INTERCEPTOR, useClass: AuditInterceptor },
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
  ],
})
export class AppModule {}
