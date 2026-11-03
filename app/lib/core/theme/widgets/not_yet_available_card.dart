import 'package:flutter/material.dart';

/// An honest placeholder for a dashboard section whose backend module
/// doesn't exist yet. Deliberately not a disabled-looking fake widget with
/// invented numbers — it says plainly that the module is pending, per
/// CLAUDE.md's prohibition on mock functionality and placeholder data.
class NotYetAvailableCard extends StatelessWidget {
  const NotYetAvailableCard({
    super.key,
    required this.title,
    required this.icon,
    required this.plannedPhase,
  });

  final String title;
  final IconData icon;
  final String plannedPhase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: theme.textTheme.bodyMedium?.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Not built yet — planned for $plannedPhase.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
