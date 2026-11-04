import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../../common/decorators/audit-action.decorator.js';
import { Roles } from '../../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { BudgetsService } from './budgets.service.js';
import { CreateBudgetDto } from './dto/create-budget.dto.js';

@Controller('workspaces/:workspaceId/budgets')
@UseGuards(WorkspaceGuard)
export class BudgetsController {
  constructor(private readonly budgetsService: BudgetsService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  @AuditAction('accounting.budget.create')
  async create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateBudgetDto) {
    return this.budgetsService.create(workspaceId, dto);
  }

  @Get()
  async findAll(@Param('workspaceId') workspaceId: string) {
    return this.budgetsService.findAll(workspaceId);
  }

  @Get(':budgetId/progress')
  async getProgress(@Param('workspaceId') workspaceId: string, @Param('budgetId') budgetId: string) {
    return this.budgetsService.getProgress(workspaceId, budgetId);
  }
}
