import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/sessions_controller.dart';
import '../../../../core/l10n/generated/app_localizations.dart';

class SessionsSection extends ConsumerWidget {
  const SessionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)!.settingsSessionsSection, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => ref.read(sessionsControllerProvider.notifier).refresh(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            sessionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Could not load sessions.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No active sessions.'));
                }
                return Column(
                  children: sessions
                      .map(
                        (session) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.smartphone_rounded),
                          title: Text(session.deviceId ?? 'Unknown device'),
                          subtitle: Text('Signed in ${_formatRelative(session.createdAt)}'),
                          trailing: TextButton(
                            onPressed: () => ref.read(sessionsControllerProvider.notifier).revoke(session.id),
                            child: Text(AppLocalizations.of(context)!.revoke),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
