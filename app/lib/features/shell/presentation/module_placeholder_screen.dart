import 'package:flutter/material.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import 'sidebar_nav.dart';

/// Honest placeholder for a sidebar destination whose module hasn't been
/// built yet. Navigating here is real (the route exists and works); the
/// module behind it is simply not implemented yet.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({super.key, required this.item});

  final SidebarNavItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(item.label(context), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.notBuiltYet, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
