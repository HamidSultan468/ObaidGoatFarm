import { NotificationCategory, NotificationSeverity, WorkspaceRole } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

export class ListNotificationsQueryDto {
  @IsOptional()
  @IsIn(['true', 'false'])
  unread?: string;

  @IsOptional()
  @IsString()
  workspaceId?: string;

  @IsOptional()
  @IsString()
  limit?: string;
}

export class CategoryPreferenceDto {
  @IsEnum(NotificationCategory)
  category!: NotificationCategory;

  @IsBoolean()
  inApp!: boolean;

  @IsBoolean()
  email!: boolean;
}

export class UpdatePreferencesDto {
  @IsOptional()
  @IsString()
  @MaxLength(60)
  timeZone?: string;

  /** Minutes after local midnight (0-1439), or null to clear. */
  @IsOptional()
  @ValidateIf((_, value) => value !== null)
  @IsInt()
  @Min(0)
  @Max(1439)
  quietHoursStart?: number | null;

  @IsOptional()
  @ValidateIf((_, value) => value !== null)
  @IsInt()
  @Min(0)
  @Max(1439)
  quietHoursEnd?: number | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => CategoryPreferenceDto)
  categories?: CategoryPreferenceDto[];
}

export class RuleDto {
  @IsEnum(NotificationCategory)
  category!: NotificationCategory;

  @IsBoolean()
  isEnabled!: boolean;

  @IsArray()
  @ArrayUnique()
  @IsEnum(WorkspaceRole, { each: true })
  recipientRoles!: WorkspaceRole[];
}

export class UpdateRulesDto {
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => RuleDto)
  rules!: RuleDto[];
}

export class SendWorkspaceNotificationDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  body!: string;

  @IsOptional()
  @IsEnum(NotificationSeverity)
  severity?: NotificationSeverity;

  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsEnum(WorkspaceRole, { each: true })
  roles?: WorkspaceRole[];

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500)
  @IsString({ each: true })
  userIds?: string[];
}

export class SendPlatformAnnouncementDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  title!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  body!: string;

  @IsOptional()
  @IsEnum(NotificationSeverity)
  severity?: NotificationSeverity;

  /** Omit to send to every active user. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(1000)
  @IsString({ each: true })
  userIds?: string[];
}
