import { BadRequestException, Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { Roles } from '../../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { FINANCE_VIEWERS } from '../../../common/roles/record-roles.js';
import { parseInclusiveRange } from '../../analytics/report-math.util.js';
import { ReportsService } from './reports.service.js';

/** Inclusive range: a date-only `to` covers that whole day (it used to stop at its first second). */
function parseDateRange(from?: string, to?: string): { from: Date; to: Date } {
  const range = parseInclusiveRange(from, to);
  if (!range) {
    throw new BadRequestException('Invalid from/to date');
  }
  return range;
}

/** Financial reports: OWNER/ADMIN/MANAGER only (DECISIONS.md D036). */
@Controller('workspaces/:workspaceId/reports')
@UseGuards(WorkspaceGuard, RolesGuard)
@Roles(...FINANCE_VIEWERS)
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('trial-balance')
  async trialBalance(@Param('workspaceId') workspaceId: string) {
    return this.reportsService.trialBalance(workspaceId);
  }

  @Get('liquid-balance')
  async liquidBalance(@Param('workspaceId') workspaceId: string) {
    return { balance: await this.reportsService.liquidBalance(workspaceId) };
  }

  @Get('profit-and-loss')
  async profitAndLoss(
    @Param('workspaceId') workspaceId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const range = parseDateRange(from, to);
    return this.reportsService.profitAndLoss(workspaceId, range.from, range.to);
  }

  @Get('cash-flow')
  async cashFlow(@Param('workspaceId') workspaceId: string, @Query('from') from?: string, @Query('to') to?: string) {
    const range = parseDateRange(from, to);
    return this.reportsService.cashFlow(workspaceId, range.from, range.to);
  }
}
