import { AnimalSex, BreedingMethod } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class CreateBreedingDto {
  @IsString()
  damId!: string;

  @IsOptional()
  @IsString()
  sireId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  externalSire?: string;

  @IsOptional()
  @IsEnum(BreedingMethod)
  method?: BreedingMethod;

  @IsDateString()
  matingDate!: string;

  /** Defaults to matingDate + 150 days when omitted. */
  @IsOptional()
  @IsDateString()
  expectedKiddingDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}

export class UpdateBreedingStatusDto {
  @IsIn(['PREGNANT', 'NOT_PREGNANT', 'ABORTED'])
  status!: 'PREGNANT' | 'NOT_PREGNANT' | 'ABORTED';

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}

export class KidDto {
  @IsString()
  @Matches(/^[A-Za-z0-9][A-Za-z0-9\-/.]{0,39}$/, { message: 'tagNumber must be 1-40 letters/digits (dash, slash, dot allowed)' })
  tagNumber!: string;

  @IsEnum(AnimalSex)
  sex!: AnimalSex;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  color?: string;
}

export class RecordKiddingDto {
  @IsDateString()
  kiddingDate!: string;

  /** Total born, including any stillborn kids that are not registered. */
  @IsInt()
  @Min(0)
  @Max(10)
  kidsBorn!: number;

  /** The live kids to register as new animals. */
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => KidDto)
  kids!: KidDto[];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  complications?: string;
}
