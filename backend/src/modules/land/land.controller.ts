import { BadRequestException, Body, Controller, Get, Headers, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import { Roles } from '../../common/decorators/roles.decorator.js';
import { RolesGuard } from '../../common/guards/roles.guard.js';
import { WorkspaceGuard } from '../../common/guards/workspace.guard.js';
import { RECORD_WRITERS } from '../../common/roles/record-roles.js';
import { AREA_UNITS, convertArea, toSquareFeet, type AreaUnitValue } from './area.util.js';
import { CreateLandParcelDto, UpdateLandParcelDto } from './dto/land.dto.js';
import { LandService } from './land.service.js';

const STATUS_FILTERS = ['ACTIVE', 'SOLD', 'LEASE_ENDED', 'ALL'];

@Controller('workspaces/:workspaceId/land')
@UseGuards(WorkspaceGuard)
export class LandController {
  constructor(private readonly landService: LandService) {}

  @Post()
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('land.parcel.create')
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateLandParcelDto) {
    return this.landService.create(workspaceId, dto);
  }

  @Get()
  findAll(@Param('workspaceId') workspaceId: string, @Query('status') status?: string) {
    if (status && !STATUS_FILTERS.includes(status)) {
      throw new BadRequestException(`status must be one of ${STATUS_FILTERS.join(', ')}`);
    }
    return this.landService.findAll(workspaceId, status ?? 'ACTIVE');
  }

  /** Pure calculator: `?value=2.5&unit=ACRE` → the area in every unit. Declared before `:parcelId`. */
  @Get('convert')
  convert(@Query('value') value?: string, @Query('unit') unit?: string) {
    if (!value || !/^\d{1,12}(\.\d{1,4})?$/.test(value) || !unit || !AREA_UNITS.includes(unit as AreaUnitValue)) {
      throw new BadRequestException(`value must be a positive decimal and unit one of ${AREA_UNITS.join(', ')}`);
    }
    return convertArea(toSquareFeet(value, unit as AreaUnitValue));
  }

  @Get('reports/profitability')
  getProfitabilityReport(
    @Param('workspaceId') workspaceId: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    for (const date of [from, to]) {
      if (date && Number.isNaN(Date.parse(date))) throw new BadRequestException('from/to must be ISO dates');
    }
    return this.landService.getProfitabilityReport(workspaceId, from, to);
  }

  @Get(':parcelId')
  findOne(@Param('workspaceId') workspaceId: string, @Param('parcelId') parcelId: string) {
    return this.landService.findOne(workspaceId, parcelId);
  }

  @Patch(':parcelId')
  @UseGuards(RolesGuard)
  @Roles(...RECORD_WRITERS)
  @AuditAction('land.parcel.update')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('parcelId') parcelId: string,
    @Body() dto: UpdateLandParcelDto,
    @Headers('if-match') ifMatch?: string,
  ) {
    return this.landService.update(workspaceId, parcelId, dto, ifMatch);
  }

  @Get(':parcelId/ledger')
  getLedger(@Param('workspaceId') workspaceId: string, @Param('parcelId') parcelId: string) {
    return this.landService.getLedger(workspaceId, parcelId);
  }
}
