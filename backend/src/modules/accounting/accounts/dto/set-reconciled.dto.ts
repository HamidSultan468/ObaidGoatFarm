import { IsBoolean } from 'class-validator';

export class SetReconciledDto {
  @IsBoolean()
  reconciled!: boolean;
}
