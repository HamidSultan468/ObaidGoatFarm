/// Generic report viewer models — deliberately mirror the backend's
/// `report-table.ts` shape exactly (title/columns/rows/totals) rather than
/// a bespoke Dart class per report. One renderer then handles all of
/// Financial Summary, Balance Sheet, Trial Balance, Farm Performance,
/// Animal Growth, Land, Audit Log and Operations — and any report added
/// later needs no new Flutter model at all, only a new entry in
/// `reportLabels` for its menu title.
library;

/// `text | money | number | decimal | percent | date | datetime` — the
/// backend's `CellType`. Money and decimal are always decimal *strings*
/// (never parsed through `double` here), exactly as the server sends them.
typedef CellType = String;

class ReportColumn {
  const ReportColumn({required this.key, required this.label, required this.type});

  final String key;
  final String label;
  final CellType type;

  factory ReportColumn.fromJson(Map<String, dynamic> json) =>
      ReportColumn(key: json['key'] as String, label: json['label'] as String, type: json['type'] as String);
}

class ReportSection {
  const ReportSection({required this.title, required this.columns, required this.rows, this.totals});

  final String title;
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? totals;

  factory ReportSection.fromJson(Map<String, dynamic> json) => ReportSection(
    title: json['title'] as String,
    columns: (json['columns'] as List).map((c) => ReportColumn.fromJson(c as Map<String, dynamic>)).toList(),
    rows: (json['rows'] as List).cast<Map<String, dynamic>>(),
    totals: (json['totals'] as Map<String, dynamic>?),
  );
}

class ReportDocument {
  const ReportDocument({required this.title, required this.workspaceName, required this.period, required this.generatedAt, required this.sections});

  final String title;
  final String workspaceName;
  final String period;
  final DateTime generatedAt;
  final List<ReportSection> sections;

  factory ReportDocument.fromJson(Map<String, dynamic> json) => ReportDocument(
    title: json['title'] as String,
    workspaceName: json['workspaceName'] as String,
    period: json['period'] as String,
    generatedAt: DateTime.parse(json['generatedAt'] as String),
    sections: (json['sections'] as List).map((s) => ReportSection.fromJson(s as Map<String, dynamic>)).toList(),
  );
}

/// `data` is the report's own typed payload (chart-friendly numbers, e.g.
/// financial-summary's monthly trend) — read ad hoc per report where a
/// richer view than the generic table is worth building (see
/// `reports_screen.dart`'s trend chart); `document` is always enough on
/// its own to show and export the report.
class ReportResult {
  const ReportResult({required this.data, required this.document});

  final Map<String, dynamic> data;
  final ReportDocument document;

  factory ReportResult.fromJson(Map<String, dynamic> json) =>
      ReportResult(data: Map<String, dynamic>.from(json['data'] as Map), document: ReportDocument.fromJson(json['document'] as Map<String, dynamic>));
}

/// Display label per backend report id — the only place a newly added
/// backend report needs a Flutter-side addition.
const reportLabels = {
  'financial-summary': 'Financial Summary',
  'balance-sheet': 'Balance Sheet',
  'trial-balance': 'Trial Balance',
  'land': 'Land Income & Expenses',
  'farm-performance': 'Farm Performance',
  'animal-growth': 'Animal Growth',
  'audit-log': 'Audit Log',
  'operations': 'Operations',
};

/// Reports that take an `asOf` date instead of a `from`/`to` range, and
/// ones that take no date parameter at all — everything else uses from/to.
const reportsWithAsOf = {'balance-sheet'};
const reportsWithNoDateParam = {'trial-balance'};
