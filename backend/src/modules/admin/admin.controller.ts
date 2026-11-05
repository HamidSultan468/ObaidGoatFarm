import { Body, Controller, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../common/decorators/current-user.decorator.js';
import { GlobalRoles } from '../../common/decorators/global-roles.decorator.js';
import { GlobalRolesGuard } from '../../common/guards/global-roles.guard.js';
import { MfaRequiredGuard } from '../../common/guards/mfa-required.guard.js';
import { AdminService } from './admin.service.js';
import { UpdateActiveStatusDto } from './dto/update-active-status.dto.js';
import { UpdateGlobalRoleDto } from './dto/update-global-role.dto.js';

/**
 * Super Admin control panel (CLAUDE.md Phase 03/04). Every route requires a
 * platform-level GlobalRole — read access for ADMIN and SUPER_ADMIN_OWNER,
 * mutations restricted to SUPER_ADMIN_OWNER and additionally gated behind
 * MfaRequiredGuard, since these are the "critical owner operations" CLAUDE.md
 * §3 requires MFA protection for.
 */
@Controller('admin')
@UseGuards(GlobalRolesGuard)
@GlobalRoles('SUPER_ADMIN_OWNER', 'ADMIN')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('workspaces')
  async listWorkspaces() {
    return this.adminService.listWorkspaces();
  }

  @Patch('workspaces/:workspaceId/status')
  @UseGuards(MfaRequiredGuard)
  @GlobalRoles('SUPER_ADMIN_OWNER')
  @AuditAction('admin.workspace.setActive')
  async setWorkspaceActive(@Param('workspaceId') workspaceId: string, @Body() dto: UpdateActiveStatusDto) {
    return this.adminService.setWorkspaceActive(workspaceId, dto.isActive);
  }

  @Get('users')
  async listUsers() {
    return this.adminService.listUsers();
  }

  @Patch('users/:userId/status')
  @UseGuards(MfaRequiredGuard)
  @GlobalRoles('SUPER_ADMIN_OWNER')
  @AuditAction('admin.user.setActive')
  async setUserActive(
    @Param('userId') userId: string,
    @Body() dto: UpdateActiveStatusDto,
    @CurrentUser() actingUser: AuthenticatedUser,
  ) {
    return this.adminService.setUserActive(userId, dto.isActive, actingUser.userId);
  }

  @Patch('users/:userId/global-role')
  @UseGuards(MfaRequiredGuard)
  @GlobalRoles('SUPER_ADMIN_OWNER')
  @AuditAction('admin.user.setGlobalRole')
  async setUserGlobalRole(
    @Param('userId') userId: string,
    @Body() dto: UpdateGlobalRoleDto,
    @CurrentUser() actingUser: AuthenticatedUser,
  ) {
    return this.adminService.setUserGlobalRole(userId, dto.globalRole as 'ADMIN' | 'USER', actingUser.userId);
  }

  /** Platform-wide system log (every workspace, not just the caller's own) — read access only, same role gate as the rest of this controller. */
  @Get('logs')
  async listLogs(
    @Query('limit') limit?: string,
    @Query('workspaceId') workspaceId?: string,
    @Query('action') action?: string,
  ) {
    const parsedLimit = limit ? Math.min(Math.max(Number.parseInt(limit, 10) || 100, 1), 500) : 100;
    return this.adminService.listLogs({ limit: parsedLimit, workspaceId, action });
  }
}
