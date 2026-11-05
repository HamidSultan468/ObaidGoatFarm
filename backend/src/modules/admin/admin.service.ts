import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';

/** Fields safe to expose to the admin console — never passwordHash or mfaSecretEncrypted. */
const SAFE_USER_SELECT = {
  id: true,
  email: true,
  fullName: true,
  globalRole: true,
  isActive: true,
  mfaEnabled: true,
  preferredLanguage: true,
  lastLoginAt: true,
  createdAt: true,
} as const;

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  /** Full detail for the Admin Console's Workspaces tab: who owns it, how its active members break down by role, and its basic activity footprint. */
  async listWorkspaces() {
    const workspaces = await this.prisma.workspace.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        users: { where: { isActive: true }, select: { role: true, user: { select: { id: true, email: true, fullName: true } } } },
        _count: { select: { animals: true, landParcels: true, journalEntries: true } },
      },
    });
    return workspaces.map(({ users, _count, ...workspace }) => {
      const owner = users.find((m) => m.role === 'OWNER')?.user;
      const roleBreakdown: Record<string, number> = {};
      for (const m of users) roleBreakdown[m.role] = (roleBreakdown[m.role] ?? 0) + 1;
      return {
        ...workspace,
        ownerEmail: owner?.email ?? null,
        ownerName: owner?.fullName ?? null,
        memberCount: users.length,
        roleBreakdown,
        animalCount: _count.animals,
        landParcelCount: _count.landParcels,
        transactionCount: _count.journalEntries,
      };
    });
  }

  async setWorkspaceActive(workspaceId: string, isActive: boolean) {
    const workspace = await this.prisma.workspace.findUnique({ where: { id: workspaceId } });
    if (!workspace) {
      throw new NotFoundException('Workspace not found');
    }
    return this.prisma.workspace.update({ where: { id: workspaceId }, data: { isActive } });
  }

  /** Full detail for the Admin Console's Users tab: every workspace this user belongs to, and as what role. */
  async listUsers() {
    const users = await this.prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      select: { ...SAFE_USER_SELECT, memberships: { where: { isActive: true }, select: { role: true, workspace: { select: { id: true, name: true } } } } },
    });
    return users.map(({ memberships, ...user }) => ({
      ...user,
      workspaces: memberships.map((m) => ({ id: m.workspace.id, name: m.workspace.name, role: m.role })),
    }));
  }

  async setUserActive(userId: string, isActive: boolean, actingUserId: string) {
    if (userId === actingUserId && !isActive) {
      throw new BadRequestException('You cannot deactivate your own account');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (user.globalRole === 'SUPER_ADMIN_OWNER' && !isActive) {
      throw new ForbiddenException('The Super Admin Owner account cannot be deactivated');
    }

    return this.prisma.user.update({ where: { id: userId }, data: { isActive }, select: SAFE_USER_SELECT });
  }

  async setUserGlobalRole(userId: string, globalRole: 'ADMIN' | 'USER', actingUserId: string) {
    if (userId === actingUserId) {
      throw new BadRequestException('You cannot change your own platform role');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (user.globalRole === 'SUPER_ADMIN_OWNER') {
      throw new ForbiddenException('The Super Admin Owner role cannot be reassigned here');
    }

    return this.prisma.user.update({ where: { id: userId }, data: { globalRole }, select: SAFE_USER_SELECT });
  }

  /** Platform-wide system log viewer: every AuditLog row, any workspace, not just one the caller belongs to — gated to SUPER_ADMIN_OWNER/ADMIN at the controller. Optional filters narrow a long history. */
  async listLogs(options: { limit: number; workspaceId?: string; action?: string }) {
    return this.prisma.auditLog.findMany({
      where: {
        workspaceId: options.workspaceId,
        action: options.action ? { contains: options.action, mode: 'insensitive' } : undefined,
      },
      orderBy: { createdAt: 'desc' },
      take: options.limit,
      include: {
        workspace: { select: { id: true, name: true } },
        user: { select: { id: true, email: true, fullName: true } },
      },
    });
  }
}
