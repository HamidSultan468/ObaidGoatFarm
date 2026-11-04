import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { FarmOverviewService } from './farm-overview.service.js';

@Controller('workspaces/:workspaceId/farm')
@UseGuards(WorkspaceGuard)
export class FarmOverviewController {
  constructor(private readonly overviewService: FarmOverviewService) {}

  @Get('overview')
  getOverview(@Param('workspaceId') workspaceId: string) {
    return this.overviewService.getOverview(workspaceId);
  }
}
