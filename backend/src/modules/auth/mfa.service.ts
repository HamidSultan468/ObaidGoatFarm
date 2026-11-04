import { BadRequestException, ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, type JwtSignOptions } from '@nestjs/jwt';
import { OTP } from 'otplib';
import { EncryptionService } from '../../common/crypto/encryption.service.js';
import { PrismaService } from '../../prisma/prisma.service.js';

const MFA_ISSUER = 'Tangent Smart Manager';
const MFA_CHALLENGE_PURPOSE = 'mfa_challenge';

interface MfaChallengePayload {
  sub: string;
  purpose: typeof MFA_CHALLENGE_PURPOSE;
}

export interface MfaSetupResult {
  secret: string;
  otpauthUrl: string;
}

@Injectable()
export class MfaService {
  private readonly totp = new OTP({ strategy: 'totp' });

  constructor(
    private readonly prisma: PrismaService,
    private readonly encryption: EncryptionService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  /** Generates a new secret and stores it encrypted, but does NOT enable MFA yet — enabling requires proving possession via verifySetup(). */
  async beginSetup(userId: string, email: string): Promise<MfaSetupResult> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    if (user.mfaEnabled) {
      throw new ConflictException('MFA is already enabled on this account');
    }

    const secret = this.totp.generateSecret();
    await this.prisma.user.update({
      where: { id: userId },
      data: { mfaSecretEncrypted: this.encryption.encrypt(secret) },
    });

    return { secret, otpauthUrl: this.totp.generateURI({ issuer: MFA_ISSUER, label: email, secret }) };
  }

  /** Confirms the user actually has the secret (via their authenticator app) before turning MFA enforcement on. */
  async verifySetup(userId: string, code: string): Promise<void> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    if (!user.mfaSecretEncrypted) {
      throw new BadRequestException('Call MFA setup first');
    }

    const secret = this.encryption.decrypt(user.mfaSecretEncrypted);
    const result = await this.totp.verify({ secret, token: code });
    if (!result.valid) {
      throw new UnauthorizedException('Invalid verification code');
    }

    await this.prisma.user.update({ where: { id: userId }, data: { mfaEnabled: true } });
  }

  /** Requires a valid current code — a hijacked session alone must not be enough to turn off MFA protection. */
  async disable(userId: string, code: string): Promise<void> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    if (!user.mfaEnabled || !user.mfaSecretEncrypted) {
      throw new BadRequestException('MFA is not enabled on this account');
    }

    const secret = this.encryption.decrypt(user.mfaSecretEncrypted);
    const result = await this.totp.verify({ secret, token: code });
    if (!result.valid) {
      throw new UnauthorizedException('Invalid verification code');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { mfaEnabled: false, mfaSecretEncrypted: null },
    });
  }

  async issueChallenge(userId: string): Promise<string> {
    const payload: MfaChallengePayload = { sub: userId, purpose: MFA_CHALLENGE_PURPOSE };
    return this.jwtService.signAsync(payload, {
      secret: this.configService.getOrThrow<string>('jwt.accessSecret'),
      expiresIn: this.configService.getOrThrow<string>('jwt.mfaChallengeExpiresIn'),
    } as JwtSignOptions);
  }

  /** Verifies the challenge token's signature/purpose/expiry, then the TOTP code, and returns the userId to issue real session tokens for. */
  async verifyChallenge(mfaToken: string, code: string): Promise<string> {
    let payload: MfaChallengePayload;
    try {
      payload = await this.jwtService.verifyAsync<MfaChallengePayload>(mfaToken, {
        secret: this.configService.getOrThrow<string>('jwt.accessSecret'),
      });
    } catch {
      throw new UnauthorizedException('MFA challenge has expired — please log in again');
    }

    if (payload.purpose !== MFA_CHALLENGE_PURPOSE) {
      throw new UnauthorizedException('Invalid MFA challenge token');
    }

    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: payload.sub } });
    if (!user.mfaEnabled || !user.mfaSecretEncrypted) {
      throw new UnauthorizedException('MFA is not enabled on this account');
    }

    const secret = this.encryption.decrypt(user.mfaSecretEncrypted);
    const result = await this.totp.verify({ secret, token: code });
    if (!result.valid) {
      throw new UnauthorizedException('Invalid verification code');
    }

    return user.id;
  }
}
