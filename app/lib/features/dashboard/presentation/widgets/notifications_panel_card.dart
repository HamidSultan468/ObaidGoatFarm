import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/notifications/notifications.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';

/// Real unread notifications (same data/actions as the bell's panel),
/// surfaced on the dashboard itself — matching the reference design's
/// notifications panel.
class NotificationsPanelCard extends ConsumerWidget {
  const NotificationsPanelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationListProvider(true));
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Notifications', style: Theme.of(context).textTheme.titleMedium)),
                TextButton(onPressed: () => context.go('/notifications'), child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 4),
            notificationsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (error, _) => Text('Could not load notifications.', style: TextStyle(color: scheme.error)),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No unread notifications.'));
                }
                return Column(
                  children: [
                    for (final n in items.take(4))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: severityIcon(n.severity, scheme),
                        title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${n.body}\n${timeAgo(n.createdAt, now)}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        isThreeLine: true,
                        onTap: () => openNotification(context, ref, n),
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
