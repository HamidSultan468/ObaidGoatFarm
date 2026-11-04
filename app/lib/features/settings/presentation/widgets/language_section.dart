import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/locale_controller.dart';

/// A genuinely functional language switch — not just a translated-but-dead
/// dropdown. Selecting a language changes the app's Locale immediately via
/// localeProvider, which MaterialApp.router watches directly.
class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final languageCode = locale?.languageCode ?? Localizations.localeOf(context).languageCode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.language_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('Language', style: Theme.of(context).textTheme.titleMedium)),
            DropdownButton<String>(
              value: languageCode == 'ur' ? 'ur' : 'en',
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ur', child: Text('اردو')),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref.read(localeProvider.notifier).setLocale(Locale(value));
              },
            ),
          ],
        ),
      ),
    );
  }
}
