import '../accounting/money_format.dart';

/// Mirrors the backend's `formatCell()` (report-table.ts) exactly, so the
/// on-screen table always reads the same as the CSV/Excel/PDF exports.
String formatReportCell(dynamic value, String type) {
  if (value == null || value == '') return '';
  final text = value.toString();
  switch (type) {
    case 'money':
      return formatMoney(text);
    case 'percent':
      return '$text%';
    case 'date':
      return text.length >= 10 ? text.substring(0, 10) : text;
    case 'datetime':
      final withSpace = text.replaceFirst('T', ' ');
      return withSpace.length >= 19 ? withSpace.substring(0, 19) : withSpace;
    default:
      return text;
  }
}

/// Numeric cell types are right-aligned; everything else is left-aligned.
bool isNumericReportCell(String type) => type == 'money' || type == 'number' || type == 'decimal' || type == 'percent';
