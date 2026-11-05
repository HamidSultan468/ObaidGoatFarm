import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accounting/accounting_controller.dart' show requireWorkspaceIdFromWidget;
import '../../../core/analytics/analytics_controller.dart';
import '../../../core/analytics/analytics_format.dart';
import '../../../core/analytics/analytics_models.dart';
import '../../../core/api/api_error.dart';
import '../../../core/theme/app_brand_colors.dart';
import '../../../core/widgets/date_field.dart';
import '../../../core/widgets/monthly_trend_chart.dart';

const _exportFormats = {'csv': 'CSV', 'xlsx': 'Excel', 'pdf': 'PDF'};
const _exportMimeTypes = {
  'csv': 'text/csv',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'pdf': 'application/pdf',
};

/// Report picker + date filters + CSV/Excel/PDF export, rendering any
/// report the backend returns (`analytics_models.dart`'s generic
/// section/column/row shape) with one table renderer — a report added
/// later needs no new screen, only a `reportLabels` entry.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _exportingFormat;

  Future<void> _export(String format) async {
    final selection = ref.read(reportSelectionProvider);
    final query = selection.toQuery();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exportingFormat = format);
    try {
      final bytes = await ref
          .read(analyticsRepositoryProvider)
          .export(requireWorkspaceIdFromWidget(ref), selection.report, format, from: query['from'], to: query['to'], asOf: query['asOf']);
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      await FilePicker.saveFile(fileName: '${selection.report}-$stamp.$format', bytes: bytes, mimeType: _exportMimeTypes[format]!);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not export the report.'))));
    } finally {
      if (mounted) setState(() => _exportingFormat = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableAsync = ref.watch(availableReportsProvider);
    final selection = ref.watch(reportSelectionProvider);

    // The report menu is role-driven server-side; if the signed-in member
    // can't open the currently selected report (e.g. switching to a STAFF
    // workspace), fall back to the first one they can.
    ref.listen(availableReportsProvider, (previous, next) {
      next.whenData((available) {
        if (available.isNotEmpty && !available.contains(ref.read(reportSelectionProvider).report)) {
          ref.read(reportSelectionProvider.notifier).selectReport(available.first);
        }
      });
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reports & Analytics', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: availableAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Could not load the report list: $error')),
              data: (available) {
                if (available.isEmpty) {
                  return const Center(child: Text('No reports are available for your role yet.'));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilterBar(available: available, selection: selection, exportingFormat: _exportingFormat, onExport: _export),
                    const SizedBox(height: 16),
                    Expanded(child: _ReportBody(reportId: selection.report)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.available, required this.selection, required this.exportingFormat, required this.onExport});

  final List<String> available;
  final ReportSelection selection;
  final String? exportingFormat;
  final Future<void> Function(String format) onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(reportSelectionProvider.notifier);
    final showAsOf = reportsWithAsOf.contains(selection.report);
    final showRange = !showAsOf && !reportsWithNoDateParam.contains(selection.report);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: selection.report,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Report'),
                items: [
                  for (final id in available)
                    DropdownMenuItem(value: id, child: Text(reportLabels[id] ?? id, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) {
                  if (value != null) controller.selectReport(value);
                },
              ),
            ),
            if (showAsOf)
              SizedBox(width: 200, child: DateField(label: 'As of', value: selection.asOf, onChanged: controller.setAsOf)),
            if (showRange) ...[
              SizedBox(
                width: 200,
                child: DateField(label: 'From', value: selection.from, onChanged: controller.setFrom, onCleared: () => controller.setFrom(null)),
              ),
              SizedBox(
                width: 200,
                child: DateField(label: 'To', value: selection.to, onChanged: controller.setTo, onCleared: () => controller.setTo(null)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final entry in _exportFormats.entries)
              OutlinedButton.icon(
                onPressed: exportingFormat == null ? () => onExport(entry.key) : null,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(entry.value),
              ),
            if (exportingFormat != null) const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          ],
        ),
      ],
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(reportResultProvider);

    return resultAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load this report: $error')),
      data: (result) {
        final trend = reportId == 'financial-summary' ? result.data['trend'] as List<dynamic>? : null;
        return ListView(
          children: [
            Text(result.document.period, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (trend != null && trend.isNotEmpty) ...[_TrendChart(trend: trend.cast<Map<String, dynamic>>()), const SizedBox(height: 16)],
            for (final section in result.document.sections) _ReportSectionCard(section: section),
          ],
        );
      },
    );
  }
}

class _ReportSectionCard extends StatelessWidget {
  const _ReportSectionCard({required this.section});
  final ReportSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (section.rows.isEmpty && section.totals == null)
              const Text('No data for this period.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [for (final c in section.columns) DataColumn(label: Text(c.label), numeric: isNumericReportCell(c.type))],
                  rows: [
                    for (final row in section.rows)
                      DataRow(cells: [for (final c in section.columns) DataCell(Text(formatReportCell(row[c.key], c.type)))]),
                    if (section.totals != null)
                      DataRow(
                        color: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
                        cells: [
                          for (final c in section.columns)
                            DataCell(Text(formatReportCell(section.totals![c.key], c.type), style: const TextStyle(fontWeight: FontWeight.w700))),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.trend});
  final List<Map<String, dynamic>> trend;

  @override
  Widget build(BuildContext context) {
    final brand = AppBrandColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Monthly trend', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TrendLegend(color: brand.income, label: 'Income'),
                const SizedBox(width: 12),
                TrendLegend(color: brand.expense, label: 'Expenses'),
                const SizedBox(width: 12),
                TrendLegend(color: brand.profit, label: 'Net'),
              ],
            ),
            const SizedBox(height: 16),
            MonthlyTrendChart(trend: trend),
          ],
        ),
      ),
    );
  }
}
