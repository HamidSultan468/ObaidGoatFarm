/// Display helpers for the Goat Farm and Land modules. Pure functions, no
/// locale/intl dependency, unit-tested in farm_format_test.dart.
library;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// `04 Nov 2026`. Uses the calendar date as sent by the API (UTC midnight),
/// so a date never shifts by a day in time zones west of UTC.
String formatDate(DateTime date) {
  final utc = date.isUtc ? date : DateTime.utc(date.year, date.month, date.day);
  return '${utc.day.toString().padLeft(2, '0')} ${_months[utc.month - 1]} ${utc.year}';
}

/// Age as `2y 3m`, `5m`, or `12d`; null when there is no birth date.
String? ageLabel(DateTime? dateOfBirth, DateTime now) {
  if (dateOfBirth == null) return null;
  final birth = DateTime.utc(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  if (today.isBefore(birth)) return null;

  var months = (today.year - birth.year) * 12 + today.month - birth.month;
  if (today.day < birth.day) months -= 1;
  if (months <= 0) return '${today.difference(birth).inDays}d';
  final years = months ~/ 12;
  final rest = months % 12;
  if (years == 0) return '${rest}m';
  return rest == 0 ? '${years}y' : '${years}y ${rest}m';
}

/// `UNDER_TREATMENT` → `Under treatment`.
String humanizeEnum(String value) {
  if (value.isEmpty) return value;
  final words = value.toLowerCase().split('_');
  return [words.first[0].toUpperCase() + words.first.substring(1), ...words.skip(1)].join(' ');
}

/// Trims a decimal string's trailing zeros for display: `33.500` → `33.5`, `40.000` → `40`.
String trimDecimal(String value) {
  if (!value.contains('.')) return value;
  final trimmed = value.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}

/// Days from [now] to [date], by calendar day (negative = in the past).
int daysUntil(DateTime date, DateTime now) {
  final target = DateTime.utc(date.year, date.month, date.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  return target.difference(today).inDays;
}

/// `in 5 days`, `today`, `3 days overdue`.
String dueLabel(DateTime date, DateTime now) {
  final days = daysUntil(date, now);
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days > 1) return 'in $days days';
  return days == -1 ? '1 day overdue' : '${-days} days overdue';
}
