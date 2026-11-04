import { Body, Controller, Delete, Get, Headers, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../../common/decorators/audit-action.decorator.js';
import { CurrentUser, type AuthenticatedUser } from '../../../common/decorators/current-user.decorator.js';
import { Roles } from '../../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { RECORD_MANAGERS, RECORD_WRITERS } from '../../../common/roles/record-roles.js';
import { AnimalsService } from './animals.service.js';
import { CreateAnimalDto, ListAnimalsQueryDto, RecordExitDto, UpdateAnimalDto } from './dto/animal.dto.js';
import { CreateHealthRecordDto, CreateWeightRecordDto } from './dto/records.dto.js';

@Controller('workspaces/:workspaceId/animals')
@UseGuards(WorkspaceGuard)
export class AnimalsController {
  constructor(private readonly animalsService: AnimalsService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('farm.animal.create')
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateAnimalDto) {
    return this.animalsService.create(workspaceId, dto);
  }

  @Get()
  findAll(@Param('workspaceId') workspaceId: string, @Query() query: ListAnimalsQueryDto) {
    return this.animalsService.findAll(workspaceId, query);
  }

  @Get(':animalId')
  findOne(@Param('workspaceId') workspaceId: string, @Param('animalId') animalId: string) {
    return this.animalsService.findOne(workspaceId, animalId);
  }

  @Patch(':animalId')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('farm.animal.update')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('animalId') animalId: string,
    @Body() dto: UpdateAnimalDto,
    @Headers('if-match') ifMatch?: string,
  ) {
    return this.animalsService.update(workspaceId, animalId, dto, ifMatch);
  }

  @Post(':animalId/exit')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_MANAGERS)
  @AuditAction('farm.animal.exit')
  recordExit(
    @Param('workspaceId') workspaceId: string,
    @Param('animalId') animalId: string,
    @Body() dto: RecordExitDto,
  ) {
    return this.animalsService.recordExit(workspaceId, animalId, dto);
  }

  @Get(':animalId/health-records')
  listHealthRecords(@Param('workspaceId') workspaceId: string, @Param('animalId') animalId: string) {
    return this.animalsService.listHealthRecords(workspaceId, animalId);
  }

  @Post(':animalId/health-records')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('farm.health.create')
  addHealthRecord(
    @Param('workspaceId') workspaceId: string,
    @Param('animalId') animalId: string,
    @CurrentUser() user: AuthenticatedUser,
    @Body() dto: CreateHealthRecordDto,
  ) {
    return this.animalsService.addHealthRecord(workspaceId, animalId, user.userId, dto);
  }

  @Delete(':animalId/health-records/:recordId')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_MANAGERS)
  @AuditAction('farm.health.delete')
  deleteHealthRecord(
    @Param('workspaceId') workspaceId: string,
    @Param('animalId') animalId: string,
    @Param('recordId') recordId: string,
  ) {
    return this.animalsService.deleteHealthRecord(workspaceId, animalId, recordId);
  }

  @Get(':animalId/weights')
  listWeights(@Param('workspaceId') workspaceId: string, @Param('animalId') animalId: string) {
    return this.animalsService.listWeights(workspaceId, animalId);
  }

  @Post(':animalId/weights')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('farm.weight.create')
  addWeight(
    @Param('workspaceId') workspaceId: string,
    @Param('animalId') animalId: string,
    @Body() dto: CreateWeightRecordDto,
  ) {
    return this.animalsService.addWeight(workspaceId, animalId, dto);
  }

  @Get(':animalId/ledger')
  getLedger(@Param('workspaceId') workspaceId: string, @Param('animalId') animalId: string) {
    return this.animalsService.getLedger(workspaceId, animalId);
  }
}
