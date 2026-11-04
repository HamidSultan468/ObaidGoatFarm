import { AreaUnit, LandStatus, LandTenure } from '@prisma/client';
import { IsDateString, IsEnum, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

/** Positive area as a decimal string (never a float), up to 4 decimals. */
const AREA_PATTERN = /^\d{1,12}(\.\d{1,4})?$/;
const AREA_MESSAGE = 'areaValue must be a positive decimal string, e.g. "12.5"';

export class CreateLandParcelDto {
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  location?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  surveyNumber?: string;

  @IsOptional()
  @IsEnum(LandTenure)
  tenure?: LandTenure;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  ownerName?: string;

  @IsString()
  @Matches(AREA_PATTERN, { message: AREA_MESSAGE })
  areaValue!: string;

  @IsEnum(AreaUnit)
  areaUnit!: AreaUnit;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  landUse?: string;

  @IsOptional()
  @IsDateString()
  acquisitionDate?: string;

  @IsOptional()
  @IsString()
  counterpartyContactId?: string;

  @IsOptional()
  @IsDateString()
  leaseStartDate?: string;

  @IsOptional()
  @IsDateString()
  leaseEndDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  leaseTerms?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

export class UpdateLandParcelDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  location?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  surveyNumber?: string;

  @IsOptional()
  @IsEnum(LandTenure)
  tenure?: LandTenure;

  @IsOptional()
  @IsEnum(LandStatus)
  status?: LandStatus;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  ownerName?: string;

  /** Must be sent together with areaUnit so the canonical value can be recomputed. */
  @IsOptional()
  @IsString()
  @Matches(AREA_PATTERN, { message: AREA_MESSAGE })
  areaValue?: string;

  @IsOptional()
  @IsEnum(AreaUnit)
  areaUnit?: AreaUnit;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  landUse?: string;

  @IsOptional()
  @IsDateString()
  acquisitionDate?: string;

  @IsOptional()
  @IsString()
  counterpartyContactId?: string;

  @IsOptional()
  @IsDateString()
  leaseStartDate?: string;

  @IsOptional()
  @IsDateString()
  leaseEndDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  leaseTerms?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}
