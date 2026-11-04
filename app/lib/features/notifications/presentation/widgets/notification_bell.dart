import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/notifications/notifications.dart';

/// How often the unread badge refreshes while the app is open.
const _pollInterval = Duration(seconds: 60);

Icon severityIcon(String severity, ColorScheme scheme) => switch (severity) {
  'CRITICAL' => Icon(Icons.error_rounded, color: scheme.error),
  'WARNING' => const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
  _ => Icon(Icons.notifications_rounded, color: scheme.primary),
};

/// Opens a notification: marks it read and follows its in-app link.
Future<void> openNotification(BuildContext context, WidgetRef ref, AppNotification n) async {
  if (!n.isRead) {
    try {
      await ref.read(notificationsRepositoryProvider).markRead(n.id);
    } catch (_) {
      // Opening still works if marking read fails; the badge refreshes later.
    }
    refreshNotifications(ref);
  }
  if (n.link != null && context.mounted) context.go(n.link!);
}

/// Top-bar bell with an unread badge and a preview panel of the latest items.
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  final _menu = MenuController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_pollInterval, (_) => ref.invalidate(unreadCountProvider));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(unreadCountProvider).value ?? 0;
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(-300, 8),
      onOpen: () => ref.invalidate(notificationListProvider(false)),
      menuChildren: [_Panel(onClose: _menu.close)],
      builder: (context, controller, _) => IconButton(
        tooltip: count == 0 ? 'Notifications' : '$count unread notifications',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: Icon(count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
        ),
      ),
    );
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationListProvider(false));
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text('Notifications', style: Theme.of(context).textTheme.titleMedium)),
                TextButton(
                  onPressed: () async {
                    await ref.read(notificationsRepositoryProvider).markAllRead(requireWorkspaceIdFromWidget(ref));
                    refreshNotifications(ref);
                  },
                  child: const Text('Mark all read'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: list.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (_, _) => const Padding(padding: EdgeInsets.all(16), child: Text('Could not load notifications.')),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(24), child: Text('You are all caught up.', textAlign: TextAlign.center));
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final n in items.take(8))
                      ListTile(
                        dense: true,
                        leading: severityIcon(n.severity, scheme),
                        title: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600),
                        ),
                        subtitle: Text('${n.body}\n${timeAgo(n.createdAt, now)}', maxLines: 3, overflow: TextOverflow.ellipsis),
                        isThreeLine: true,
                        tileColor: n.isRead ? null : scheme.primaryContainer.withValues(alpha: 0.25),
                        onTap: () {
                          onClose();
                          openNotification(context, ref, n);
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          TextButton(
            onPressed: () {
              onClose();
              context.go('/notifications');
            },
            child: const Text('View all'),
          ),
        ],
      ),
    );
  }
}
