import { BadRequestException, Controller, ForbiddenException, Get, Param, Query, Req, Res, UseGuards } from '@nestjs/common';
import type { WorkspaceRole } from '@prisma/client';
import type { Request, Response } from 'express';
import { AuditAction } from '../../common/decorators/audit-action.decorator.js';
import type { WorkspaceMembershipContext } from '../../common/guards/workspace.guard.js';
import { WorkspaceGuard } from '../../common/guards/workspace.guard.js';
import { AUDIT_VIEWERS, FARM_REPORT_VIEWERS, FINANCE_VIEWERS } from '../../common/roles/record-roles.js';
import { AnalyticsService } from './analytics.service.js';
import { toCsv } from './exporters/csv.exporter.js';
import { toPdf } from './exporters/pdf.exporter.js';
import { toXlsx } from './exporters/xlsx.exporter.js';
import { parseInclusiveRange } from './report-math.util.js';
import type { ReportDocument } from './report-table.js';

/** Who may open each report (server-side, per request). */
const REPORT_ACCESS: Record<string, WorkspaceRole[]> = {
  'financial-summary': FINANCE_VIEWERS,
  'balance-sheet': FINANCE_VIEWERS,
  'trial-balance': FINANCE_VIEWERS,
  land: FINANCE_VIEWERS,
  'farm-performance': FARM_REPORT_VIEWERS,
  'animal-growth': FARM_REPORT_VIEWERS,
  'audit-log': AUDIT_VIEWERS,
  operations: AUDIT_VIEWERS,
};

const FORMATS = {
  csv: { contentType: 'text/csv; charset=utf-8', render: (d: ReportDocument) => Promise.resolve(toCsv(d)) },
  xlsx: { contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', render: (d: ReportDocument) => Promise.resolve(toXlsx(d)) },
  pdf: { contentType: 'application/pdf', render: toPdf },
} as const;

type ReportRequest = Request & { membership?: WorkspaceMembershipContext };

@Controller('workspaces/:workspaceId/analytics')
@UseGuards(WorkspaceGuard)
export class AnalyticsController {
  constructor(private readonly analytics: AnalyticsService) {}

  /** Report names this member may open (drives the app's report menu). */
  @Get()
  available(@Req() req: ReportRequest) {
    const role = req.membership!.role;
    return Object.entries(REPORT_ACCESS)
      .filter(([, roles]) => roles.includes(role))
      .map(([name]) => name);
  }

  @Get(':report')
  async report(
    @Param('workspaceId') workspaceId: string,
    @Param('report') report: string,
    @Req() req: ReportRequest,
    @Query() query: Record<string, string | undefined>,
  ) {
    return this.build(workspaceId, report, req.membership!.role, query);
  }

  @Get(':report/export')
  @AuditAction('report.export')
  async export(
    @Param('workspaceId') workspaceId: string,
    @Param('report') report: string,
    @Req() req: ReportRequest,
    @Query() query: Record<string, string | undefined>,
    @Res() res: Response,
  ) {
    const format = FORMATS[(query.format ?? '') as keyof typeof FORMATS];
    if (!format) throw new BadRequestException('format must be csv, xlsx or pdf');
    const { document } = await this.build(workspaceId, report, req.membership!.role, query);
    const file = await format.render(document);
    const stamp = new Date().toISOString().slice(0, 10);
    res.set({
      'Content-Type': format.contentType,
      'Content-Length': String(file.length),
      'Content-Disposition': `attachment; filename="${report}-${stamp}.${query.format}"`,
      'Cache-Control': 'private, no-store',
      'X-Content-Type-Options': 'nosniff',
    });
    res.end(file);
  }

  private async build(workspaceId: string, report: string, role: WorkspaceRole, query: Record<string, string | undefined>) {
    const allowed = REPORT_ACCESS[report];
    if (!allowed) throw new BadRequestException(`Unknown report "${report}"`);
    if (!allowed.includes(role)) throw new ForbiddenException('Your role cannot open this report');

    if (report === 'balance-sheet') {
      const asOf = parseInclusiveRange('2000-01-01', query.asOf);
      if (!asOf) throw new BadRequestException('asOf must be a date (YYYY-MM-DD)');
      return this.analytics.balanceSheet(workspaceId, asOf.to);
    }
    if (report === 'trial-balance') return this.analytics.trialBalance(workspaceId);

    const range = parseInclusiveRange(query.from, query.to);
    if (!range) throw new BadRequestException('from/to must be dates (YYYY-MM-DD) with from on or before to');
    switch (report) {
      case 'financial-summary':
        return this.analytics.financialSummary(workspaceId, range);
      case 'land':
        return this.analytics.landReport(workspaceId, range);
      case 'farm-performance':
        return this.analytics.farmPerformance(workspaceId, range, FINANCE_VIEWERS.includes(role));
      case 'animal-growth':
        return this.analytics.animalGrowth(workspaceId, range);
      case 'audit-log':
        return this.analytics.auditLog(workspaceId, range, query.action?.slice(0, 100));
      default:
        return this.analytics.operations(workspaceId, range);
    }
  }
}
