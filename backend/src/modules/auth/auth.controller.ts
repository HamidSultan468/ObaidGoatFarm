import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../common/decorators/current-user.decorator.js';
import { Public } from '../../common/decorators/public.decorator.js';
import { AuthService } from './auth.service.js';
import { LoginDto } from './dto/login.dto.js';
import { MfaLoginDto } from './dto/mfa-login.dto.js';
import { MfaVerifyDto } from './dto/mfa-verify.dto.js';
import { RefreshTokenDto } from './dto/refresh-token.dto.js';
import { RegisterDto } from './dto/register.dto.js';
import { MfaService } from './mfa.service.js';

function extractDeviceId(request: Request): string | undefined {
  const deviceId = request.headers['x-device-id'];
  return typeof deviceId === 'string' ? deviceId : undefined;
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly mfaService: MfaService,
  ) {}

  /** Lets a client holding a still-valid access token restore its session
   * with fresh profile data, without re-prompting for credentials. */
  @Get('me')
  async me(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.getProfile(user.userId);
  }

  @Public()
  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  /** Returns either real session tokens, or `{ mfaRequired: true, mfaToken }` if the account has MFA enabled — see POST /auth/mfa/login. */
  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto, @Req() request: Request) {
    return this.authService.login(dto, extractDeviceId(request));
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto.refreshToken);
  }

  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Body() dto: RefreshTokenDto): Promise<void> {
    await this.authService.logout(dto.refreshToken);
  }

  /** Step two of login for an MFA-enabled account: exchanges the challenge token + a TOTP code for real session tokens. */
  @Public()
  @Post('mfa/login')
  @HttpCode(HttpStatus.OK)
  async mfaLogin(@Body() dto: MfaLoginDto, @Req() request: Request) {
    return this.authService.loginWithMfa(dto.mfaToken, dto.code, extractDeviceId(request));
  }

  /** Starts MFA enrollment: generates and stores (encrypted) a new TOTP secret, not yet enforced until verify-setup succeeds. */
  @Post('mfa/setup')
  @AuditAction('auth.mfa.setup')
  async mfaSetup(@CurrentUser() user: AuthenticatedUser) {
    return this.mfaService.beginSetup(user.userId, user.email);
  }

  @Post('mfa/verify-setup')
  @HttpCode(HttpStatus.NO_CONTENT)
  @AuditAction('auth.mfa.enable')
  async mfaVerifySetup(@CurrentUser() user: AuthenticatedUser, @Body() dto: MfaVerifyDto): Promise<void> {
    await this.mfaService.verifySetup(user.userId, dto.code);
  }

  @Post('mfa/disable')
  @HttpCode(HttpStatus.NO_CONTENT)
  @AuditAction('auth.mfa.disable')
  async mfaDisable(@CurrentUser() user: AuthenticatedUser, @Body() dto: MfaVerifyDto): Promise<void> {
    await this.mfaService.disable(user.userId, dto.code);
  }

  /** Lists the caller's active sessions (one per non-revoked refresh token) — the basis for "log out this device" / device management. */
  @Get('sessions')
  async listSessions(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.listSessions(user.userId);
  }

  @Delete('sessions/:sessionId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @AuditAction('auth.session.revoke')
  async revokeSession(@CurrentUser() user: AuthenticatedUser, @Param('sessionId') sessionId: string): Promise<void> {
    await this.authService.revokeSession(user.userId, sessionId);
  }
}
