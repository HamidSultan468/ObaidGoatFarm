import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../accounting/accounting_controller.dart';
import '../auth/auth_controller.dart';
import '../farm/farm_repository.dart' show apiDate;
import 'analytics_models.dart';
import 'analytics_repository.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) => AnalyticsRepository(ref.watch(apiClientProvider)));

/// Report ids the signed-in member may open in this workspace.
final availableReportsProvider = FutureProvider<List<String>>((ref) {
  return ref.read(analyticsRepositoryProvider).availableReports(requireWorkspaceId(ref));
});

/// Which report is showing, and the date range/as-of date it's showing for.
/// `from`/`to` null means "the backend's default" (current calendar month
/// to now); `asOf` null means "as of today" for Balance Sheet.
class ReportSelection {
  const ReportSelection({required this.report, this.from, this.to, this.asOf});

  final String report;
  final DateTime? from;
  final DateTime? to;
  final DateTime? asOf;

  ReportSelection copyWith({String? report, DateTime? from, DateTime? to, DateTime? asOf, bool clearFrom = false, bool clearTo = false, bool clearAsOf = false}) =>
      ReportSelection(
        report: report ?? this.report,
        from: clearFrom ? null : (from ?? this.from),
        to: clearTo ? null : (to ?? this.to),
        asOf: clearAsOf ? null : (asOf ?? this.asOf),
      );

  /// Query parameters for both the on-screen fetch and the export download
  /// — always identical, so "what you see is what you export".
  Map<String, String> toQuery() => {
    if (!reportsWithNoDateParam.contains(report) && !reportsWithAsOf.contains(report)) ...{
      if (from != null) 'from': apiDate(from!),
      if (to != null) 'to': apiDate(to!),
    },
    if (reportsWithAsOf.contains(report) && asOf != null) 'asOf': apiDate(asOf!),
  };
}

final reportSelectionProvider = NotifierProvider<ReportSelectionController, ReportSelection>(ReportSelectionController.new);

class ReportSelectionController extends Notifier<ReportSelection> {
  @override
  ReportSelection build() => const ReportSelection(report: 'financial-summary');

  void selectReport(String report) => state = ReportSelection(report: report);
  void setFrom(DateTime? value) => state = state.copyWith(from: value, clearFrom: value == null);
  void setTo(DateTime? value) => state = state.copyWith(to: value, clearTo: value == null);
  void setAsOf(DateTime? value) => state = state.copyWith(asOf: value, clearAsOf: value == null);
}

final reportResultProvider = FutureProvider<ReportResult>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  final selection = ref.watch(reportSelectionProvider);
  final query = selection.toQuery();
  return ref.read(analyticsRepositoryProvider).fetch(workspaceId, selection.report, from: query['from'], to: query['to'], asOf: query['asOf']);
});
