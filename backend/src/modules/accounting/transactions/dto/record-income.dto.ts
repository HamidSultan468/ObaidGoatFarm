import { IsBoolean, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

const DECIMAL_PATTERN = /^\d+(\.\d{1,4})?$/;

export class RecordIncomeDto {
  /** Where the money landed — typically a CASH or BANK account. */
  @IsString()
  @MinLength(1)
  toAccountId!: string;

  /** Which INCOME account to credit (e.g. Sales Income). */
  @IsString()
  @MinLength(1)
  incomeAccountId!: string;

  @IsString()
  @Matches(DECIMAL_PATTERN, { message: 'amount must be a positive decimal string, e.g. "1250.00"' })
  amount!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  memo?: string;

  @IsOptional()
  @IsString()
  contactId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  documentNumber?: string;

  @IsOptional()
  @IsBoolean()
  issueReceipt?: boolean;

  /** Optional Goat Farm tag (per-animal profitability). */
  @IsOptional()
  @IsString()
  animalId?: string;

  /** Optional Land tag (per-parcel profitability). */
  @IsOptional()
  @IsString()
  landParcelId?: string;
}
