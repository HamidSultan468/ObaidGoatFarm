import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../../common/decorators/current-user.decorator.js';
import { Roles } from '../../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { UpdateAccountStatusDto } from '../accounts/dto/update-account-status.dto.js';
import { CreateRecurringTemplateDto } from './dto/create-recurring-template.dto.js';
import { RecurringService } from './recurring.service.js';

@Controller('workspaces/:workspaceId/recurring-templates')
@UseGuards(WorkspaceGuard)
export class RecurringController {
  constructor(private readonly recurringService: RecurringService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  @AuditAction('accounting.recurring.create')
  async create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateRecurringTemplateDto) {
    return this.recurringService.create(workspaceId, dto);
  }

  @Get()
  async findAll(@Param('workspaceId') workspaceId: string) {
    return this.recurringService.findAll(workspaceId);
  }

  @Patch(':templateId/status')
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  @AuditAction('accounting.recurring.setStatus')
  async setActive(
    @Param('workspaceId') workspaceId: string,
    @Param('templateId') templateId: string,
    @Body() dto: UpdateAccountStatusDto,
  ) {
    return this.recurringService.setActive(workspaceId, templateId, dto.isActive);
  }

  @Post(':templateId/run-now')
  @UseGuards(RolesGuard)
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  @AuditAction('accounting.recurring.runNow')
  async runNow(
    @Param('workspaceId') workspaceId: string,
    @Param('templateId') templateId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.recurringService.runNow(workspaceId, templateId, user.userId);
  }
}
