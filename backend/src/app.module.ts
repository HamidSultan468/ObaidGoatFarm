import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import configuration from './config/configuration.js';
import { validateEnv } from './config/env.validation.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { CryptoModule } from './common/crypto/crypto.module.js';
import { AccountingModule } from './modules/accounting/accounting.module.js';
import { IdempotencyCleanupService } from './common/idempotency/idempotency-cleanup.service.js';
import { IdempotencyInterceptor } from './common/idempotency/idempotency.interceptor.js';
import { AiModule } from './modules/ai/ai.module.js';
import { AnalyticsModule } from './modules/analytics/analytics.module.js';
import { BackupModule } from './modules/backup/backup.module.js';
import { DocumentsModule } from './modules/documents/documents.module.js';
import { FarmModule } from './modules/farm/farm.module.js';
import { LandModule } from './modules/land/land.module.js';
import { NotificationsModule } from './modules/notifications/notifications.module.js';
import { WhatsAppModule } from './modules/whatsapp/whatsapp.module.js';
import { AdminModule } from './modules/admin/admin.module.js';
import { AuthModule } from './modules/auth/auth.module.js';
import { HealthModule } from './modules/health/health.module.js';
import { WorkspacesModule } from './modules/workspaces/workspaces.module.js';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard.js';
import { AuditInterceptor } from './common/interceptors/audit.interceptor.js';
import { HttpExceptionFilter } from './common/filters/http-exception.filter.js';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validate: validateEnv,
    }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 100 }]),
    CryptoModule,
    PrismaModule,
    AuthModule,
    HealthModule,
    WorkspacesModule,
    AdminModule,
    AccountingModule,
    FarmModule,
    LandModule,
    DocumentsModule,
    NotificationsModule,
    BackupModule,
    AiModule,
    WhatsAppModule,
    AnalyticsModule,
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
    // Order matters: idempotency first, so a replayed request is not audited twice.
    { provide: APP_INTERCEPTOR, useClass: IdempotencyInterceptor },
    { provide: APP_INTERCEPTOR, useClass: AuditInterceptor },
    IdempotencyCleanupService,
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
  ],
})
export class AppModule {}
