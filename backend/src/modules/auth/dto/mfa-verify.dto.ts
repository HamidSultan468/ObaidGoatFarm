import { IsString, Length } from 'class-validator';

export class MfaVerifyDto {
  /** A 6-digit TOTP code from the user's authenticator app. */
  @IsString()
  @Length(6, 6)
  code!: string;
}
