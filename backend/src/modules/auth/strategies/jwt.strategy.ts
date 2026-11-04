import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../../prisma/prisma.service.js';
import type { AuthenticatedUser } from '../../../common/decorators/current-user.decorator.js';

interface JwtPayload {
  sub: string;
  email: string;
  /** Only ever set on purpose-scoped tokens (e.g. the MFA challenge token —
   * see MfaService.issueChallenge). A real access token never carries this,
   * so any payload that does must be rejected here — otherwise a
   * purpose-scoped token, signed with the same secret, would work as a
   * full bearer token anywhere and silently defeat MFA. */
  purpose?: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('jwt.accessSecret'),
    });
  }

  async validate(payload: JwtPayload): Promise<AuthenticatedUser> {
    if (payload.purpose) {
      throw new UnauthorizedException('This token cannot be used as a bearer token');
    }

    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });

    if (!user || !user.isActive) {
      throw new UnauthorizedException('Account is inactive or no longer exists');
    }

    return { userId: user.id, email: user.email, globalRole: user.globalRole, mfaEnabled: user.mfaEnabled };
  }
}
