import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/notifications/notifications.dart' show timeAgo;
import '../../../../core/offline/connectivity_controller.dart';
import '../../../../core/offline/outbox_controller.dart';
import '../../../../core/offline/outbox_models.dart';

/// Top-bar indicator for CLAUDE.md Phase 13's "provide clear synchronization
/// status": shows offline / pending / all-synced, and opens the outbox list
/// (retry or discard a queued write) on tap. Hidden entirely once there is
/// nothing pending and the device is online — a quiet app, not a noisy one.
class SyncStatus extends ConsumerWidget {
  const SyncStatus({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).value ?? true;
    final items = ref.watch(outboxControllerProvider);
    final pending = items.where((i) => i.status != OutboxStatus.failed).length;
    final failed = items.where((i) => i.status == OutboxStatus.failed).length;

    if (online && items.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final (icon, color, label) = !online
        ? (Icons.cloud_off_rounded, scheme.error, 'Offline${pending > 0 ? ' · $pending pending' : ''}')
        : failed > 0
        ? (Icons.sync_problem_rounded, scheme.error, '$failed need attention')
        : (Icons.sync_rounded, const Color(0xFFD97706), 'Syncing $pending…');

    return IconButton(
      tooltip: label,
      onPressed: () => showModalBottomSheet<void>(context: context, builder: (_) => const _OutboxSheet(), isScrollControlled: true),
      icon: compact
          ? Badge(isLabelVisible: items.isNotEmpty, label: Text('${items.length}'), child: Icon(icon, color: color))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon, color: color, size: 20), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 13))],
            ),
    );
  }
}

class _OutboxSheet extends ConsumerWidget {
  const _OutboxSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(outboxControllerProvider);
    final online = ref.watch(connectivityProvider).value ?? true;
    final now = DateTime.now();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Pending sync', style: Theme.of(context).textTheme.titleMedium)),
                  if (online && items.any((i) => i.status != OutboxStatus.sending))
                    TextButton(
                      onPressed: () => ref.read(outboxControllerProvider.notifier).processQueue(),
                      child: const Text('Sync now'),
                    ),
                ],
              ),
            ),
            if (!online)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('No connection right now. These will send automatically once you\'re back online.', style: Theme.of(context).textTheme.bodySmall),
              ),
            Flexible(
              child: items.isEmpty
                  ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nothing pending — everything is synced.')))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: Icon(switch (item.status) {
                            OutboxStatus.failed => Icons.error_outline_rounded,
                            OutboxStatus.sending => Icons.sync_rounded,
                            OutboxStatus.pending => Icons.schedule_rounded,
                          }),
                          title: Text(item.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text([
                            timeAgo(item.createdAt, now),
                            if (item.lastError != null) item.lastError!,
                          ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: item.status == OutboxStatus.sending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : PopupMenuButton<String>(
                                  onSelected: (action) {
                                    final notifier = ref.read(outboxControllerProvider.notifier);
                                    if (action == 'retry') notifier.retry(item.id);
                                    if (action == 'discard') notifier.discard(item.id);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'retry', child: Text('Retry now')),
                                    PopupMenuItem(value: 'discard', child: Text('Discard')),
                                  ],
                                ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
