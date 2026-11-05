import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/farm/farm_format.dart';
import '../../../../core/workspace/workspace_controller.dart';

/// Dashboard widget: how many active members this workspace has and how
/// they break down by role — a quick-glance summary of the Staff tab's data.
class TeamSummaryCard extends ConsumerWidget {
  const TeamSummaryCard({super.key, required this.workspaceId});
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(workspaceMembersProvider(workspaceId));
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Team', style: Theme.of(context).textTheme.titleMedium)),
                TextButton(onPressed: () => context.go('/staff'), child: const Text('Open')),
              ],
            ),
            const SizedBox(height: 8),
            members.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (error, _) => Text('Could not load the team.', style: TextStyle(color: scheme.error)),
              data: (list) {
                final byRole = <String, int>{};
                for (final m in list) {
                  byRole[m.role] = (byRole[m.role] ?? 0) + 1;
                }
                String plural(String role, int count) {
                  final label = humanizeEnum(role);
                  if (count <= 1 || role == 'STAFF') return label;
                  return '${label}s';
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in byRole.entries) Chip(label: Text('${entry.value} ${plural(entry.key, entry.value)}')),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
