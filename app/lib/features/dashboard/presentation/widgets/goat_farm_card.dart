import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/farm/farm_controller.dart';
import '../../../../core/farm/farm_format.dart';

/// Dashboard widget (FR-4.6): live herd counts and the next few farm tasks.
class GoatFarmCard extends ConsumerWidget {
  const GoatFarmCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(farmOverviewProvider);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pets_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Goat Farm', style: Theme.of(context).textTheme.titleMedium)),
                TextButton(onPressed: () => context.go('/goat-farm'), child: const Text('Open')),
              ],
            ),
            const SizedBox(height: 4),
            overview.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (error, _) => Text('Could not load farm data.', style: TextStyle(color: scheme.error)),
              data: (o) {
                final now = DateTime.now();
                final tasks = [
                  for (final d in o.dueHealth) (d.nextDueDate, '${humanizeEnum(d.type)} · ${d.animal.label}', d.overdue),
                  for (final k in o.upcomingKiddings) (k.expectedKiddingDate, 'Kidding · ${k.dam.label}', false),
                ]..sort((a, b) => a.$1.compareTo(b.$1));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${o.activeAnimals} animals · ${o.females} F / ${o.males} M · ${o.pregnant} pregnant'
                      '${o.needsAttention > 0 ? ' · ${o.needsAttention} need attention' : ''}',
                    ),
                    const SizedBox(height: 8),
                    if (tasks.isEmpty)
                      Text('Nothing due in the next 30 days.', style: Theme.of(context).textTheme.bodySmall)
                    else
                      for (final task in tasks.take(4))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(task.$2, overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            dueLabel(task.$1, now),
                            style: TextStyle(color: task.$3 ? scheme.error : null),
                          ),
                        ),
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
