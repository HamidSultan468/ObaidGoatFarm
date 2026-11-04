import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../../common/decorators/current-user.decorator.js';
import { Roles } from '../../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { CreateManualEntryDto } from './dto/create-manual-entry.dto.js';
import { RecordExpenseDto } from './dto/record-expense.dto.js';
import { RecordIncomeDto } from './dto/record-income.dto.js';
import { RecordTransferDto } from './dto/record-transfer.dto.js';
import { TransactionsService } from './transactions.service.js';

@Controller('workspaces/:workspaceId/transactions')
@UseGuards(WorkspaceGuard)
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Post('income')
  @AuditAction('accounting.transaction.recordIncome')
  async recordIncome(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: RecordIncomeDto,
  ) {
    return this.transactionsService.recordIncome(workspaceId, user.userId, dto);
  }

  @Post('expense')
  @AuditAction('accounting.transaction.recordExpense')
  async recordExpense(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: RecordExpenseDto,
  ) {
    return this.transactionsService.recordExpense(workspaceId, user.userId, dto);
  }

  @Post('transfer')
  @AuditAction('accounting.transaction.recordTransfer')
  async recordTransfer(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: RecordTransferDto,
  ) {
    return this.transactionsService.recordTransfer(workspaceId, user.userId, dto);
  }

  @Post('manual')
  @AuditAction('accounting.transaction.createManual')
  async createManualEntry(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateManualEntryDto,
  ) {
    return this.transactionsService.createManualEntry(workspaceId, user.userId, dto);
  }

  @Get()
  async findAll(@Param('workspaceId') workspaceId: string, @Query('limit') limit?: string) {
    const parsedLimit = limit ? Number.parseInt(limit, 10) : undefined;
    return this.transactionsService.findAll(workspaceId, parsedLimit);
  }

  @Get('pending-approvals')
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN')
  async listPendingApprovals(@Param('workspaceId') workspaceId: string) {
    return this.transactionsService.listPendingApprovals(workspaceId);
  }

  @Get(':entryId')
  async findOne(@Param('workspaceId') workspaceId: string, @Param('entryId') entryId: string) {
    return this.transactionsService.findOne(workspaceId, entryId);
  }

  @Post(':entryId/reverse')
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @AuditAction('accounting.transaction.reverse')
  async reverse(
    @Param('workspaceId') workspaceId: string,
    @Param('entryId') entryId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.transactionsService.reverse(workspaceId, entryId, user.userId);
  }

  @Post(':entryId/approve')
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @AuditAction('accounting.transaction.approve')
  async approve(
    @Param('workspaceId') workspaceId: string,
    @Param('entryId') entryId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.transactionsService.approve(workspaceId, entryId, user.userId);
  }

  @Post(':entryId/reject')
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @AuditAction('accounting.transaction.reject')
  async reject(
    @Param('workspaceId') workspaceId: string,
    @Param('entryId') entryId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.transactionsService.reject(workspaceId, entryId, user.userId);
  }
}
