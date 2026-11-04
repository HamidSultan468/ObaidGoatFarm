import 'package:flutter/material.dart';
import '../farm/farm_format.dart';

/// A read-only field that opens a date picker. [value] null shows "Not set";
/// pass [onCleared] to allow clearing an optional date.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onCleared,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback? onCleared;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(now.year - 30),
      lastDate: lastDate ?? DateTime(now.year + 5),
    );
    if (picked != null) onChanged(DateTime.utc(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value != null && onCleared != null
              ? IconButton(icon: const Icon(Icons.clear_rounded), tooltip: 'Clear', onPressed: onCleared)
              : const Icon(Icons.calendar_today_rounded),
        ),
        child: Text(value == null ? 'Not set' : formatDate(value!)),
      ),
    );
  }
}
