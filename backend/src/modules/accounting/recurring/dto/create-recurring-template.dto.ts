import { IsDateString, IsEnum, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { JournalEntryType, RecurrenceFrequency } from '@prisma/client';

const DECIMAL_PATTERN = /^\d+(\.\d{1,4})?$/;

export class CreateRecurringTemplateDto {
  @IsString()
  @MinLength(1)
  @MaxLength(150)
  name!: string;

  @IsEnum(JournalEntryType)
  entryType!: JournalEntryType;

  @IsString()
  @MinLength(1)
  fromAccountId!: string;

  @IsString()
  @MinLength(1)
  toAccountId!: string;

  @IsOptional()
  @IsString()
  contactId?: string;

  @IsString()
  @Matches(DECIMAL_PATTERN, { message: 'amount must be a positive decimal string' })
  amount!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  memo?: string;

  @IsEnum(RecurrenceFrequency)
  frequency!: RecurrenceFrequency;

  @IsDateString()
  nextRunDate!: string;
}
