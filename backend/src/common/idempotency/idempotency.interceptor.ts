import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  UnprocessableEntityException,
  type CallHandler,
  type ExecutionContext,
  type NestInterceptor,
} from '@nestjs/common';
import { HTTP_CODE_METADATA } from '@nestjs/common/constants.js';
import { Reflector } from '@nestjs/core';
import { Prisma } from '@prisma/client';
import type { Request, Response } from 'express';
import { from, lastValueFrom, type Observable } from 'rxjs';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../decorators/current-user.decorator.js';
import { IDEMPOTENCY_KEY_PATTERN, IDEMPOTENCY_TTL_MS, requestHash } from './idempotency.util.js';

/**
 * Makes any authenticated POST safe to retry when the client sends an
 * `Idempotency-Key` header (the offline outbox always does):
 *  - first request: runs normally; its status and body are stored;
 *  - same key + same request again: the stored response is replayed
 *    (header `Idempotent-Replayed: true`) and nothing runs twice;
 *  - same key + different request: 422;
 *  - same key while the first is still running: 409.
 * A request that fails is forgotten, so it can be corrected and retried.
 *
 * Registered before the audit interceptor, so a replay is not audited twice.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  private readonly logger = new Logger(IdempotencyInterceptor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const http = context.switchToHttp();
    const request = http.getRequest<Request & { user?: AuthenticatedUser }>();
    const key = request.header('idempotency-key');
    if (request.method !== 'POST' || !key || !request.user) return next.handle();
    if (!IDEMPOTENCY_KEY_PATTERN.test(key)) {
      throw new BadRequestException('Idempotency-Key must be 8-100 letters, digits, "-" or "_"');
    }
    // Nest applies a POST's status (201, or @HttpCode) only when sending, so read it from the route.
    const status = this.reflector.get<number>(HTTP_CODE_METADATA, context.getHandler()) ?? 201;
    return from(this.handle(request, http.getResponse<Response>(), key, next, status));
  }

  private async handle(request: Request & { user?: AuthenticatedUser }, response: Response, key: string, next: CallHandler, status: number): Promise<unknown> {
    const userId = request.user!.userId;
    const path = request.originalUrl.split('?')[0];
    const hash = requestHash(request.method, path, request.body);

    const existing = await this.prisma.idempotencyRecord.findUnique({ where: { userId_key: { userId, key } } });
    if (existing && existing.createdAt.getTime() < Date.now() - IDEMPOTENCY_TTL_MS) {
      await this.prisma.idempotencyRecord.delete({ where: { id: existing.id } });
    } else if (existing) {
      if (existing.requestHash !== hash) throw new UnprocessableEntityException('This Idempotency-Key was already used for a different request');
      if (existing.statusCode === null) throw new ConflictException('A request with this Idempotency-Key is still being processed');
      response.status(existing.statusCode);
      response.setHeader('Idempotent-Replayed', 'true');
      return existing.responseBody;
    }

    let recordId: string;
    try {
      recordId = (await this.prisma.idempotencyRecord.create({ data: { userId, key, method: request.method, path, requestHash: hash } })).id;
    } catch (error) {
      // Two identical retries racing: the loser waits for the winner's stored result.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('A request with this Idempotency-Key is still being processed');
      }
      throw error;
    }

    try {
      const body = await lastValueFrom(next.handle(), { defaultValue: null });
      await this.prisma.idempotencyRecord.update({
        where: { id: recordId },
        data: { statusCode: status, responseBody: (body ?? null) as Prisma.InputJsonValue },
      });
      return body;
    } catch (error) {
      await this.prisma.idempotencyRecord.delete({ where: { id: recordId } }).catch((e: Error) => this.logger.warn(`Could not release key: ${e.message}`));
      throw error;
    }
  }
}

