import 'package:flutter/material.dart';

/// Honest placeholder for a sidebar destination whose module hasn't been
/// built yet. Navigating here is real (the route exists and works); the
/// module behind it is simply not implemented yet.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('This module is not built yet.', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
