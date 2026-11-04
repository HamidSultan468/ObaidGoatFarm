import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../../common/decorators/audit-action.decorator.js';
import { Roles } from '../../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { RECORD_WRITERS } from '../../../common/roles/record-roles.js';
import { BreedingService } from './breeding.service.js';
import { CreateBreedingDto, RecordKiddingDto, UpdateBreedingStatusDto } from './dto/breeding.dto.js';

@Controller('workspaces/:workspaceId/breeding')
@UseGuards(WorkspaceGuard)
export class BreedingController {
  constructor(private readonly breedingService: BreedingService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('farm.breeding.create')
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateBreedingDto) {
    return this.breedingService.create(workspaceId, dto);
  }

  /** `?open=true` returns only MATED/PREGNANT records. */
  @Get()
  findAll(@Param('workspaceId') workspaceId: string, @Query('open') open?: string) {
    return this.breedingService.findAll(workspaceId, open === 'true');
  }

  @Patch(':recordId/status')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('farm.breeding.updateStatus')
  updateStatus(
    @Param('workspaceId') workspaceId: string,
    @Param('recordId') recordId: string,
    @Body() dto: UpdateBreedingStatusDto,
  ) {
    return this.breedingService.updateStatus(workspaceId, recordId, dto);
  }

  @Post(':recordId/kidding')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('farm.breeding.recordKidding')
  recordKidding(
    @Param('workspaceId') workspaceId: string,
    @Param('recordId') recordId: string,
    @Body() dto: RecordKiddingDto,
  ) {
    return this.breedingService.recordKidding(workspaceId, recordId, dto);
  }
}
