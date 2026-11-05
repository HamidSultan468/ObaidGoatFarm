import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../../common/decorators/audit-action.decorator.js';
import { Roles } from '../../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { AccountsService } from './accounts.service.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { SetReconciledDto } from './dto/set-reconciled.dto.js';
import { UpdateAccountStatusDto } from './dto/update-account-status.dto.js';

@Controller('workspaces/:workspaceId/accounts')
@UseGuards(WorkspaceGuard)
export class AccountsController {
  constructor(private readonly accountsService: AccountsService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @AuditAction('accounting.account.create')
  async create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateAccountDto) {
    return this.accountsService.create(workspaceId, dto);
  }

  @Get()
  async findAll(@Param('workspaceId') workspaceId: string) {
    return this.accountsService.findAll(workspaceId);
  }

  @Get(':accountId')
  async findOne(@Param('workspaceId') workspaceId: string, @Param('accountId') accountId: string) {
    return this.accountsService.findOne(workspaceId, accountId);
  }

  @Get(':accountId/balance')
  async getBalance(@Param('workspaceId') workspaceId: string, @Param('accountId') accountId: string) {
    const balance = await this.accountsService.getBalance(workspaceId, accountId);
    return { accountId, balance: balance.toFixed(4) };
  }

  @Get(':accountId/statement')
  async getStatement(
    @Param('workspaceId') workspaceId: string,
    @Param('accountId') accountId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.accountsService.getStatement(
      workspaceId,
      accountId,
      from ? new Date(from) : undefined,
      to ? new Date(to) : undefined,
    );
  }

  @Patch(':accountId/lines/:lineId/reconcile')
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  @AuditAction('accounting.line.setReconciled')
  async setLineReconciled(
    @Param('workspaceId') workspaceId: string,
    @Param('accountId') accountId: string,
    @Param('lineId') lineId: string,
    @Body() dto: SetReconciledDto,
  ) {
    return this.accountsService.setLineReconciled(workspaceId, accountId, lineId, dto.reconciled);
  }

  @Patch(':accountId/status')
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @AuditAction('accounting.account.setStatus')
  async setActive(
    @Param('workspaceId') workspaceId: string,
    @Param('accountId') accountId: string,
    @Body() dto: UpdateAccountStatusDto,
  ) {
    return this.accountsService.setActive(workspaceId, accountId, dto.isActive);
  }
}
