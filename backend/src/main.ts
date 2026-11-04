import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module.js';

const LOCALHOST_ORIGIN_PATTERN = /^https?:\/\/(localhost|127\.0\.0\.1):\d+$/;

/**
 * In development, `flutter run -d chrome` picks an arbitrary port per run,
 * so a fixed CORS_ORIGIN allowlist would need updating every time. Any
 * localhost origin is allowed only when NODE_ENV=development; every other
 * environment enforces the explicit CORS_ORIGIN allowlist, which
 * `env.validation.ts` now requires at boot — the `?? []` below is a
 * defense-in-depth fallback (deny all, never wildcard-allow) that should be
 * unreachable in practice.
 */
function resolveCorsOrigin(): boolean | string[] | RegExp {
  if (process.env.NODE_ENV === 'development') {
    return LOCALHOST_ORIGIN_PATTERN;
  }
  return process.env.CORS_ORIGIN?.split(',').map((origin) => origin.trim()) ?? [];
}

async function bootstrap() {
  // rawBody: the WhatsApp webhook verifies Meta's HMAC over the exact bytes received.
  const app = await NestFactory.create(AppModule, { rawBody: true });

  app.use(helmet());
  app.enableCors({ origin: resolveCorsOrigin(), credentials: true });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      // No implicit conversion: it silently turned a JSON number (a float)
      // into a string, letting it pass the decimal-string checks on money
      // and weights. Amounts must arrive as strings (DECISIONS.md D022).
      transformOptions: { enableImplicitConversion: false },
    }),
  );
  app.enableShutdownHooks();

  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
