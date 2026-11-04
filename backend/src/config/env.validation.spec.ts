import 'reflect-metadata';
import { describe, expect, it } from 'vitest';
import { validateEnv } from './env.validation.js';

const base = {
  NODE_ENV: 'production',
  PORT: '3000',
  DATABASE_URL: 'postgres://u:p@localhost:5432/db',
  ENCRYPTION_KEY: 'a'.repeat(64),
  JWT_ACCESS_SECRET: 'secret',
  JWT_REFRESH_SECRET: 'secret',
  JWT_ACCESS_EXPIRES_IN: '15m',
  JWT_REFRESH_EXPIRES_IN: '30d',
};

describe('env validation — CORS_ORIGIN', () => {
  it('is required outside development: refuses to start wide open', () => {
    expect(() => validateEnv(base)).toThrow(/CORS_ORIGIN/);
  });

  it('is accepted when set in production', () => {
    expect(() => validateEnv({ ...base, CORS_ORIGIN: 'https://app.example.com' })).not.toThrow();
  });

  it('is not required in development (any-localhost CORS applies instead — D020)', () => {
    expect(() => validateEnv({ ...base, NODE_ENV: 'development' })).not.toThrow();
  });
});
