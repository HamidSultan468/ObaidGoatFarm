import { HealthRecordType } from '@prisma/client';
import { IsDateString, IsEnum, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class CreateHealthRecordDto {
  @IsEnum(HealthRecordType)
  type!: HealthRecordType;

  @IsDateString()
  recordDate!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  description!: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  medication?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  dosage?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  veterinarian?: string;

  /** When the next dose / follow-up is due; feeds the farm schedule. */
  @IsOptional()
  @IsDateString()
  nextDueDate?: string;
}

/** Positive kilograms with up to 3 decimals, sent as a string (never a float). */
const WEIGHT_PATTERN = /^\d{1,4}(\.\d{1,3})?$/;

export class CreateWeightRecordDto {
  @IsDateString()
  recordDate!: string;

  @IsString()
  @Matches(WEIGHT_PATTERN, { message: 'weightKg must be a positive decimal string with up to 3 decimals, e.g. "32.500"' })
  weightKg!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}
