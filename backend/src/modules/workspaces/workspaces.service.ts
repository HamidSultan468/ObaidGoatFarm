import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { CreateWorkspaceDto } from './dto/create-workspace.dto.js';
import type { InviteMemberDto } from './dto/invite-member.dto.js';

const SLUG_COLLISION_RETRY_LIMIT = 20;

@Injectable()
export class WorkspacesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(ownerUserId: string, dto: CreateWorkspaceDto) {
    const slug = await this.resolveUniqueSlug(dto.slug ?? dto.name);

    return this.prisma.workspace.create({
      data: {
        name: dto.name,
        slug,
        users: {
          create: { userId: ownerUserId, role: 'OWNER', acceptedAt: new Date() },
        },
      },
    });
  }

  async findAllForUser(userId: string) {
    return this.prisma.workspace.findMany({
      where: { users: { some: { userId, isActive: true } }, isActive: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  async findOne(workspaceId: string) {
    const workspace = await this.prisma.workspace.findUnique({ where: { id: workspaceId } });
    if (!workspace || !workspace.isActive) {
      throw new NotFoundException('Workspace not found');
    }
    return workspace;
  }

  async inviteMember(workspaceId: string, dto: InviteMemberDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) {
      throw new NotFoundException('No account exists for that email yet — they must register first');
    }

    const existing = await this.prisma.workspaceMembership.findUnique({
      where: { userId_workspaceId: { userId: user.id, workspaceId } },
    });
    if (existing) {
      throw new ConflictException('This user is already a member of the workspace');
    }

    return this.prisma.workspaceMembership.create({
      data: { userId: user.id, workspaceId, role: dto.role },
    });
  }

  private async resolveUniqueSlug(source: string): Promise<string> {
    const base = this.slugify(source);

    for (let attempt = 0; attempt < SLUG_COLLISION_RETRY_LIMIT; attempt++) {
      const candidate = attempt === 0 ? base : `${base}-${attempt + 1}`;
      const existing = await this.prisma.workspace.findUnique({ where: { slug: candidate } });
      if (!existing) {
        return candidate;
      }
    }

    throw new ForbiddenException('Could not generate a unique workspace identifier — try a different name');
  }

  private slugify(value: string): string {
    const slug = value
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');

    return slug.length > 0 ? slug.slice(0, 60) : 'workspace';
  }
}
