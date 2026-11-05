import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../common/decorators/current-user.decorator.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../common/guards/workspace.guard.js';
import { CreateWorkspaceDto } from './dto/create-workspace.dto.js';
import { InviteMemberDto } from './dto/invite-member.dto.js';
import { UpdateMemberRoleDto } from './dto/update-member-role.dto.js';
import { WorkspacesService } from './workspaces.service.js';

@Controller('workspaces')
export class WorkspacesController {
  constructor(private readonly workspacesService: WorkspacesService) {}

  @Post()
  @AuditAction('workspace.create')
  async create(@CurrentUser() user: AuthenticatedUser, @Body() dto: CreateWorkspaceDto) {
    return this.workspacesService.create(user.userId, dto);
  }

  @Get()
  async findMine(@CurrentUser() user: AuthenticatedUser) {
    return this.workspacesService.findAllForUser(user.userId);
  }

  @Get(':workspaceId')
  @UseGuards(WorkspaceGuard)
  async findOne(@Param('workspaceId') workspaceId: string) {
    return this.workspacesService.findOne(workspaceId);
  }

  @Post(':workspaceId/members')
  @UseGuards(WorkspaceGuard, RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @AuditAction('workspace.member.invite')
  async inviteMember(@Param('workspaceId') workspaceId: string, @Body() dto: InviteMemberDto) {
    return this.workspacesService.inviteMember(workspaceId, dto);
  }

  /** The "Staff" tab's data — every active member, any role may view. */
  @Get(':workspaceId/members')
  @UseGuards(WorkspaceGuard)
  async listMembers(@Param('workspaceId') workspaceId: string) {
    return this.workspacesService.listMembers(workspaceId);
  }

  @Patch(':workspaceId/members/:membershipId/role')
  @UseGuards(WorkspaceGuard, RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @AuditAction('workspace.member.setRole')
  async setMemberRole(
    @Param('workspaceId') workspaceId: string,
    @Param('membershipId') membershipId: string,
    @Body() dto: UpdateMemberRoleDto,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    return this.workspacesService.setMemberRole(workspaceId, membershipId, dto.role, user.userId);
  }

  @Delete(':workspaceId/members/:membershipId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(WorkspaceGuard, RolesGuard)
  @Roles('OWNER', 'ADMIN')
  @AuditAction('workspace.member.remove')
  async removeMember(
    @Param('workspaceId') workspaceId: string,
    @Param('membershipId') membershipId: string,
    @CurrentUser() user: AuthenticatedUser,
  ) {
    await this.workspacesService.removeMember(workspaceId, membershipId, user.userId);
  }
}
