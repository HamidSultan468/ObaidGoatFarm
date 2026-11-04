import { IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

const DECIMAL_PATTERN = /^\d+(\.\d{1,4})?$/;

export class RecordExpenseDto {
  /** Where the money came from — typically a CASH or BANK account. */
  @IsString()
  @MinLength(1)
  fromAccountId!: string;

  /** Which EXPENSE account to debit. */
  @IsString()
  @MinLength(1)
  expenseAccountId!: string;

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

  /** Optional Goat Farm tag (per-animal profitability). */
  @IsOptional()
  @IsString()
  animalId?: string;

  /** Optional Land tag (per-parcel profitability). */
  @IsOptional()
  @IsString()
  landParcelId?: string;
}
