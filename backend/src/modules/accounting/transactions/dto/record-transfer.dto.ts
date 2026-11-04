import { IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

const DECIMAL_PATTERN = /^\d+(\.\d{1,4})?$/;

export class RecordTransferDto {
  @IsString()
  @MinLength(1)
  fromAccountId!: string;

  @IsString()
  @MinLength(1)
  toAccountId!: string;

  @IsString()
  @Matches(DECIMAL_PATTERN, { message: 'amount must be a positive decimal string, e.g. "1250.00"' })
  amount!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  memo?: string;
}
