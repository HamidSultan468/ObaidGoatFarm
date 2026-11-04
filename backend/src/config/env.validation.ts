import { plainToInstance } from 'class-transformer';
import { IsEmail, IsIn, IsInt, IsNotEmpty, IsOptional, IsString, Matches, Max, Min, ValidateIf, validateSync } from 'class-validator';

class EnvironmentVariables {
  @IsIn(['development', 'test', 'production'])
  NODE_ENV!: string;

  @IsInt()
  @Min(1)
  @Max(65535)
  PORT!: number;

  @IsString()
  @IsNotEmpty()
  DATABASE_URL!: string;

  @Matches(/^[0-9a-fA-F]{64}$/, { message: 'ENCRYPTION_KEY must be a 64-character hex string (32 bytes)' })
  ENCRYPTION_KEY!: string;

  @IsString()
  @IsNotEmpty()
  JWT_ACCESS_SECRET!: string;

  @IsString()
  @IsNotEmpty()
  JWT_REFRESH_SECRET!: string;

  @IsString()
  @IsNotEmpty()
  JWT_ACCESS_EXPIRES_IN!: string;

  @IsString()
  @IsNotEmpty()
  JWT_REFRESH_EXPIRES_IN!: string;

  // Outside development, `main.ts` has no safe default for this — an unset
  // CORS_ORIGIN there would otherwise silently allow every origin. Dev mode
  // allows any localhost port instead (DECISIONS.md D020), so this is moot
  // there.
  @ValidateIf((o: EnvironmentVariables) => o.NODE_ENV !== 'development')
  @IsString()
  @IsNotEmpty({ message: 'CORS_ORIGIN is required outside development (comma-separated allowed origins) — refusing to start wide open' })
  CORS_ORIGIN?: string;

  // Email notifications (optional). Email stays disabled until SMTP_HOST is set.
  @IsOptional()
  @IsString()
  SMTP_HOST?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(65535)
  SMTP_PORT?: number;

  @IsOptional()
  @IsIn(['true', 'false'])
  SMTP_SECURE?: string;

  @IsOptional()
  @IsString()
  SMTP_USER?: string;

  @IsOptional()
  @IsString()
  SMTP_PASS?: string;

  @IsOptional()
  @IsEmail()
  SMTP_FROM?: string;
}

/**
 * Fails fast at boot if required configuration is missing or malformed,
 * instead of letting the app start into a half-configured, insecure state.
 */
export function validateEnv(config: Record<string, unknown>): EnvironmentVariables {
  const validated = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validated, { skipMissingProperties: false });

  if (errors.length > 0) {
    throw new Error(
      `Invalid environment configuration:\n${errors
        .map((error) => Object.values(error.constraints ?? {}).join(', '))
        .join('\n')}`,
    );
  }

  return validated;
}
