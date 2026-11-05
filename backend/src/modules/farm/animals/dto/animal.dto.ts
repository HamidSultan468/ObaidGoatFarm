import { AnimalAcquisition, AnimalHealthStatus, AnimalSex } from '@prisma/client';
import { IsDateString, IsEnum, IsIn, IsOptional, IsString, Matches, MaxLength, MinLength, ValidateIf } from 'class-validator';

/** Tag numbers: letters, digits, dash, slash, dot. Keeps them printable and URL/QR-safe. */
const TAG_PATTERN = /^[A-Za-z0-9][A-Za-z0-9\-/.]{0,39}$/;

export class CreateAnimalDto {
  @IsString()
  @Matches(TAG_PATTERN, { message: 'tagNumber must be 1-40 letters/digits (dash, slash, dot allowed)' })
  tagNumber!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  species?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  breed?: string;

  @IsEnum(AnimalSex)
  sex!: AnimalSex;

  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  color?: string;

  @IsOptional()
  @IsEnum(AnimalHealthStatus)
  healthStatus?: AnimalHealthStatus;

  @IsOptional()
  @IsEnum(AnimalAcquisition)
  acquisition?: AnimalAcquisition;

  @IsOptional()
  @IsDateString()
  acquisitionDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  ownership?: string;

  @IsOptional()
  @IsString()
  sireId?: string;

  @IsOptional()
  @IsString()
  damId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  dietaryRestrictions?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

/** Every field optional; status changes go through RecordExitDto instead. */
export class UpdateAnimalDto {
  @IsOptional()
  @IsString()
  @Matches(TAG_PATTERN, { message: 'tagNumber must be 1-40 letters/digits (dash, slash, dot allowed)' })
  tagNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(40)
  species?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  breed?: string;

  @IsOptional()
  @IsEnum(AnimalSex)
  sex?: AnimalSex;

  @IsOptional()
  @IsDateString()
  dateOfBirth?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  color?: string;

  @IsOptional()
  @IsEnum(AnimalHealthStatus)
  healthStatus?: AnimalHealthStatus;

  @IsOptional()
  @IsEnum(AnimalAcquisition)
  acquisition?: AnimalAcquisition;

  @IsOptional()
  @IsDateString()
  acquisitionDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  ownership?: string;

  @IsOptional()
  @IsString()
  sireId?: string;

  @IsOptional()
  @IsString()
  damId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  dietaryRestrictions?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;

  /** Id of an existing Attachment (module=ANIMAL, recordId=this animal) to set as the profile photo; null clears it. */
  @IsOptional()
  @ValidateIf((_, value) => value !== null)
  @IsString()
  photoAttachmentId?: string | null;
}

export class RecordExitDto {
  @IsIn(['SOLD', 'DECEASED'])
  status!: 'SOLD' | 'DECEASED';

  @IsDateString()
  exitDate!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  exitReason?: string;
}

export class ListAnimalsQueryDto {
  @IsOptional()
  @IsIn(['ACTIVE', 'SOLD', 'DECEASED', 'ALL'])
  status?: 'ACTIVE' | 'SOLD' | 'DECEASED' | 'ALL';

  @IsOptional()
  @IsString()
  @MaxLength(80)
  search?: string;
}
