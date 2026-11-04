import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { randomUUID } from 'node:crypto';

interface NormalizedErrorBody {
  statusCode: number;
  code: string;
  message: string;
  correlationId: string;
  details?: unknown;
}

/**
 * Normalizes every error response to a single shape and logs it server-side
 * with a correlation ID, so client-facing messages never leak internals
 * while operators can still trace the failure.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const correlationId = randomUUID();

    const isHttpException = exception instanceof HttpException;
    const statusCode = isHttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;

    const body: NormalizedErrorBody = {
      statusCode,
      code: isHttpException ? exception.constructor.name : 'INTERNAL_SERVER_ERROR',
      message: isHttpException ? exception.message : 'An unexpected error occurred',
      correlationId,
    };

    if (isHttpException) {
      const response_ = exception.getResponse();
      if (typeof response_ === 'object' && response_ !== null) {
        // Field-level problems go to `details`: either class-validator's
        // message array, or an explicit `errors` list from a service
        // (draft approval, backup verification).
        const { message, errors } = response_ as { message?: unknown; errors?: unknown };
        if (Array.isArray(message)) {
          body.details = message;
        } else if (Array.isArray(errors)) {
          body.details = errors;
        }
      }
    }

    this.logger.error(
      `[${correlationId}] ${request.method} ${request.url} -> ${statusCode}`,
      exception instanceof Error ? exception.stack : String(exception),
    );

    response.status(statusCode).json(body);
  }
}
