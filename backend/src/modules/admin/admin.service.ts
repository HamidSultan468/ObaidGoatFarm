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

  async listWorkspaces() {
    return this.prisma.workspace.findMany({
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { users: true } } },
    });
  }

  async setWorkspaceActive(workspaceId: string, isActive: boolean) {
    const workspace = await this.prisma.workspace.findUnique({ where: { id: workspaceId } });
    if (!workspace) {
      throw new NotFoundException('Workspace not found');
    }
    return this.prisma.workspace.update({ where: { id: workspaceId }, data: { isActive } });
  }

  async listUsers() {
    return this.prisma.user.findMany({ orderBy: { createdAt: 'desc' }, select: SAFE_USER_SELECT });
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
}
