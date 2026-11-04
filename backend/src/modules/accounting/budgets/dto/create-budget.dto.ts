import { IsDateString, IsString, Matches, MinLength } from 'class-validator';

const DECIMAL_PATTERN = /^\d+(\.\d{1,4})?$/;

export class CreateBudgetDto {
  @IsString()
  @MinLength(1)
  accountId!: string;

  @IsDateString()
  periodStart!: string;

  @IsDateString()
  periodEnd!: string;

  @IsString()
  @Matches(DECIMAL_PATTERN, { message: 'amount must be a positive decimal string' })
  amount!: string;
}
