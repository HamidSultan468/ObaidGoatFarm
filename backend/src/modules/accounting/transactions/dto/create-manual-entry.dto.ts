import { Type } from 'class-transformer';
import { ArrayMinSize, IsArray, IsOptional, IsString, Matches, MaxLength, MinLength, ValidateNested } from 'class-validator';

const DECIMAL_PATTERN = /^-?\d+(\.\d{1,4})?$/;

export class ManualEntryLineDto {
  @IsString()
  @MinLength(1)
  accountId!: string;

  /** Positive = debit, negative = credit. */
  @IsString()
  @Matches(DECIMAL_PATTERN, { message: 'amount must be a decimal string, e.g. "100.00" or "-100.00"' })
  amount!: string;
}

export class CreateManualEntryDto {
  @IsArray()
  @ArrayMinSize(2, { message: 'A journal entry needs at least two lines' })
  @ValidateNested({ each: true })
  @Type(() => ManualEntryLineDto)
  lines!: ManualEntryLineDto[];

  @IsOptional()
  @IsString()
  @MaxLength(500)
  memo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  documentNumber?: string;

  @IsOptional()
  @IsString()
  contactId?: string;

  /** Optional Goat Farm tag (per-animal profitability). */
  @IsOptional()
  @IsString()
  animalId?: string;

  /** Optional Land tag (per-parcel profitability). */
  @IsOptional()
  @IsString()
  landParcelId?: string;
}
