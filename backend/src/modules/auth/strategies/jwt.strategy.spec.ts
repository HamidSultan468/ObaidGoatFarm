import 'reflect-metadata';
import { UnauthorizedException } from '@nestjs/common';
import { describe, expect, it, vi } from 'vitest';
import { JwtStrategy } from './jwt.strategy.js';

function makeStrategy(user: { id: string; isActive: boolean } | null) {
  const configService = { getOrThrow: () => 'test-secret' };
  const prisma = { user: { findUnique: vi.fn().mockResolvedValue(user) } };
  return { strategy: new JwtStrategy(configService as never, prisma as never), prisma };
}

describe('JwtStrategy — purpose-scoped tokens must never work as a bearer token', () => {
  it('accepts a real access token payload (no purpose claim)', async () => {
    const { strategy } = makeStrategy({ id: 'u1', isActive: true });
    const result = await strategy.validate({ sub: 'u1', email: 'a@b.com' });
    expect(result.userId).toBe('u1');
  });

  it('rejects any payload carrying a purpose claim — e.g. an MFA challenge token — before even looking up the user', async () => {
    const { strategy, prisma } = makeStrategy({ id: 'u1', isActive: true });
    await expect(strategy.validate({ sub: 'u1', email: 'a@b.com', purpose: 'mfa_challenge' })).rejects.toThrow(UnauthorizedException);
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it('rejects a deactivated user even without a purpose claim', async () => {
    const { strategy } = makeStrategy({ id: 'u1', isActive: false });
    await expect(strategy.validate({ sub: 'u1', email: 'a@b.com' })).rejects.toThrow(UnauthorizedException);
  });
});
