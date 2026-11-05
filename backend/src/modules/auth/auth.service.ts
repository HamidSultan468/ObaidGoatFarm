import { ConflictException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, type JwtSignOptions } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { createHash, randomBytes } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MfaService } from './mfa.service.js';
import type { LoginDto } from './dto/login.dto.js';
import type { RegisterDto } from './dto/register.dto.js';

const BCRYPT_ROUNDS = 12;
const REFRESH_TOKEN_BYTES = 64;

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthenticatedProfile {
  id: string;
  email: string;
  fullName: string;
  globalRole: string;
  preferredLanguage: string;
  mfaEnabled: boolean;
}

export interface MfaRequiredResult {
  mfaRequired: true;
  mfaToken: string;
}

export type LoginResult = MfaRequiredResult | (AuthTokens & { profile: AuthenticatedProfile });

export interface DeviceInfo {
  deviceName?: string;
  platform?: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly mfaService: MfaService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthenticatedProfile> {
    const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existing) {
      throw new ConflictException('An account with this email already exists');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        fullName: dto.fullName,
        preferredLanguage: dto.preferredLanguage ?? 'en',
      },
    });

    return this.toProfile(user);
  }

  async login(dto: LoginDto, deviceId?: string, deviceInfo?: DeviceInfo): Promise<LoginResult> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const passwordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!passwordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    if (user.mfaEnabled) {
      // Password alone is not enough — hand back a short-lived challenge
      // token instead of real session tokens until the TOTP code is
      // verified via POST /auth/mfa/login.
      return { mfaRequired: true, mfaToken: await this.mfaService.issueChallenge(user.id) };
    }

    await this.prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });

    const tokens = await this.issueTokens(user.id, user.email, deviceId, deviceInfo);
    return { ...tokens, profile: this.toProfile(user) };
  }

  async loginWithMfa(
    mfaToken: string,
    code: string,
    deviceId?: string,
    deviceInfo?: DeviceInfo,
  ): Promise<AuthTokens & { profile: AuthenticatedProfile }> {
    const userId = await this.mfaService.verifyChallenge(mfaToken, code);
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });

    await this.prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });

    const tokens = await this.issueTokens(user.id, user.email, deviceId, deviceInfo);
    return { ...tokens, profile: this.toProfile(user) };
  }

  async refresh(rawRefreshToken: string): Promise<AuthTokens> {
    const tokenHash = this.hashToken(rawRefreshToken);
    const stored = await this.prisma.refreshToken.findUnique({ where: { tokenHash } });

    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token is invalid or expired');
    }

    const user = await this.prisma.user.findUnique({ where: { id: stored.userId } });
    if (!user || !user.isActive) {
      throw new UnauthorizedException('Account is inactive or no longer exists');
    }

    // Rotate: revoke the used token and issue a fresh pair, so a replayed
    // (stolen) refresh token can only ever be used once.
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: { revokedAt: new Date() },
    });

    return this.issueTokens(user.id, user.email, stored.deviceId ?? undefined);
  }

  /**
   * A "session" here is an active (not revoked, not expired) refresh token,
   * enriched with the friendly device name/platform the client reported at
   * login (`UserDevice`, keyed on the same `deviceId` the session itself
   * carries) when available — an older session, or one from a client that
   * never sent device metadata, just falls back to the raw deviceId.
   */
  async listSessions(userId: string) {
    const [sessions, devices] = await Promise.all([
      this.prisma.refreshToken.findMany({
        where: { userId, revokedAt: null, expiresAt: { gt: new Date() } },
        orderBy: { createdAt: 'desc' },
        select: { id: true, deviceId: true, createdAt: true, expiresAt: true },
      }),
      this.prisma.userDevice.findMany({ where: { userId } }),
    ]);
    const deviceById = new Map(devices.map((d) => [d.deviceId, d]));
    return sessions.map((session) => ({
      ...session,
      deviceName: session.deviceId ? (deviceById.get(session.deviceId)?.deviceName ?? null) : null,
      platform: session.deviceId ? (deviceById.get(session.deviceId)?.platform ?? null) : null,
    }));
  }

  async revokeSession(userId: string, sessionId: string): Promise<void> {
    const session = await this.prisma.refreshToken.findUnique({ where: { id: sessionId } });
    if (!session || session.userId !== userId) {
      throw new NotFoundException('Session not found');
    }
    await this.prisma.refreshToken.update({ where: { id: sessionId }, data: { revokedAt: new Date() } });
  }

  async getProfile(userId: string): Promise<AuthenticatedProfile> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return this.toProfile(user);
  }

  async logout(rawRefreshToken: string): Promise<void> {
    const tokenHash = this.hashToken(rawRefreshToken);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private async issueTokens(userId: string, email: string, deviceId?: string, deviceInfo?: DeviceInfo): Promise<AuthTokens> {
    const accessToken = await this.jwtService.signAsync(
      { sub: userId, email },
      {
        secret: this.configService.getOrThrow<string>('jwt.accessSecret'),
        expiresIn: this.configService.getOrThrow<string>('jwt.accessExpiresIn'),
      } as JwtSignOptions,
    );

    const rawRefreshToken = randomBytes(REFRESH_TOKEN_BYTES).toString('hex');
    const refreshExpiresIn = this.configService.getOrThrow<string>('jwt.refreshExpiresIn');

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: this.hashToken(rawRefreshToken),
        deviceId,
        expiresAt: this.parseExpiryToDate(refreshExpiresIn),
      },
    });

    if (deviceId && deviceInfo?.deviceName && deviceInfo.platform) {
      await this.prisma.userDevice.upsert({
        where: { userId_deviceId: { userId, deviceId } },
        create: { userId, deviceId, deviceName: deviceInfo.deviceName, platform: deviceInfo.platform },
        update: { deviceName: deviceInfo.deviceName, platform: deviceInfo.platform, lastSeenAt: new Date() },
      });
    }

    return { accessToken, refreshToken: rawRefreshToken };
  }

  /** Refresh tokens are stored as a SHA-256 hash, never in plaintext. */
  private hashToken(rawToken: string): string {
    return createHash('sha256').update(rawToken).digest('hex');
  }

  private parseExpiryToDate(duration: string): Date {
    const match = /^(\d+)([smhd])$/.exec(duration);
    if (!match) {
      throw new Error(`Invalid duration format: ${duration}`);
    }
    const [, amountStr, unit] = match;
    const amount = Number.parseInt(amountStr, 10);
    const unitMs: Record<string, number> = { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 };
    return new Date(Date.now() + amount * unitMs[unit]);
  }

  private toProfile(user: {
    id: string;
    email: string;
    fullName: string;
    globalRole: string;
    preferredLanguage: string;
    mfaEnabled: boolean;
  }): AuthenticatedProfile {
    return {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      globalRole: user.globalRole,
      preferredLanguage: user.preferredLanguage,
      mfaEnabled: user.mfaEnabled,
    };
  }
}
