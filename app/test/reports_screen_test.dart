import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/analytics/analytics_controller.dart';
import 'package:app/core/analytics/analytics_models.dart';
import 'package:app/core/analytics/analytics_repository.dart';
import 'package:app/core/api/api_client.dart';
import 'package:app/core/workspace/workspace_controller.dart';
import 'package:app/core/workspace/workspace_models.dart';
import 'package:app/features/reports/presentation/reports_screen.dart';

import 'test_helpers.dart';

const _workspace = Workspace(id: 'ws-1', name: 'Test Farm', slug: 'test-farm');

class _ScriptedWorkspaceController extends WorkspaceController {
  @override
  WorkspaceState build() => const WorkspaceSelected(_workspace, [_workspace]);
}

/// A report per id, so switching the dropdown is observably different —
/// proves the screen actually refetches on selection, not just that it
/// renders once.
ReportResult _resultFor(String reportId) => ReportResult(
  data: const {'trend': []},
  document: ReportDocument(
    title: reportLabels[reportId] ?? reportId,
    workspaceName: 'Test Farm',
    period: '01 Nov 2026 – 04 Nov 2026',
    generatedAt: DateTime.utc(2026, 11, 4),
    sections: [
      ReportSection(
        title: reportId == 'financial-summary' ? 'Summary' : 'Herd movement',
        columns: const [ReportColumn(key: 'metric', label: 'Metric', type: 'text'), ReportColumn(key: 'value', label: 'Amount', type: 'money')],
        rows: [
          {'metric': reportId == 'financial-summary' ? 'Total income' : 'Animals added', 'value': '741159.8400'},
        ],
        totals: const {'metric': 'Total', 'value': '741159.8400'},
      ),
    ],
  ),
);

class _FakeAnalyticsRepository extends AnalyticsRepository {
  _FakeAnalyticsRepository() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));

  final fetchedReports = <String>[];

  @override
  Future<List<String>> availableReports(String workspaceId) async => const ['financial-summary', 'farm-performance'];

  @override
  Future<ReportResult> fetch(String workspaceId, String report, {String? from, String? to, String? asOf, String? action}) async {
    fetchedReports.add(report);
    return _resultFor(report);
  }

  @override
  Future<Uint8List> export(String workspaceId, String report, String format, {String? from, String? to, String? asOf, String? action}) async =>
      Uint8List.fromList('fake file'.codeUnits);
}

Future<_FakeAnalyticsRepository> _pumpReportsScreen(WidgetTester tester) async {
  final repository = _FakeAnalyticsRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsRepositoryProvider.overrideWithValue(repository),
        workspaceControllerProvider.overrideWith(_ScriptedWorkspaceController.new),
      ],
      child: const MaterialApp(home: Scaffold(body: ReportsScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('shows the default report with its sections, rows and totals', (tester) async {
    await _pumpReportsScreen(tester);

    expect(find.text('Financial Summary'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Total income'), findsOneWidget);
    expect(find.text('741,159.84'), findsNWidgets(2)); // the row and the totals row
  });

  testWidgets('the report picker only offers reports the role can open, and switching refetches', (tester) async {
    final repository = await _pumpReportsScreen(tester);
    expect(repository.fetchedReports, ['financial-summary']);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Report'));
    await tester.pumpAndSettle();
    // Only the two reports the fake's availableReports() returned are offered.
    expect(find.text('Financial Summary'), findsNWidgets(2)); // field + menu item
    expect(find.text('Farm Performance'), findsOneWidget);
    expect(find.text('Balance Sheet'), findsNothing);

    await tester.tap(find.text('Farm Performance').last);
    await tester.pumpAndSettle();

    expect(repository.fetchedReports, ['financial-summary', 'farm-performance']);
    expect(find.text('Herd movement'), findsOneWidget);
    expect(find.text('Animals added'), findsOneWidget);
  });
}
