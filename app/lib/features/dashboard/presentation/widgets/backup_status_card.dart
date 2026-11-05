import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/backup/backup.dart';
import '../../../../core/documents/documents.dart';
import '../../../../core/notifications/notifications.dart';

/// Dashboard backup widget (owners/admins): last backup, health, storage used.
class BackupStatusCard extends ConsumerWidget {
  const BackupStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backupStatusProvider);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_done_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Cloud Backup Status', style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 12),
            status.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text('Could not load backup status.', style: TextStyle(color: scheme.error)),
              data: (s) {
                final failed = s.lastBackup?.status == 'FAILED';
                final last = s.lastSuccessfulBackup;
                final badgeColor = failed ? scheme.error : (last == null ? const Color(0xFFD97706) : const Color(0xFF22A559));
                final badgeText = failed ? 'Failed' : (last == null ? 'Not set up' : 'Protected');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          failed ? Icons.error_rounded : (last == null ? Icons.warning_amber_rounded : Icons.check_circle_rounded),
                          size: 22,
                          color: badgeColor,
                        ),
                        const SizedBox(width: 8),
                        Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(last == null ? 'No backup yet' : 'Last backup: ${timeAgo(last.startedAt, DateTime.now())}'),
                    const SizedBox(height: 4),
                    Text(
                      '${s.autoBackupEnabled ? 'Daily automatic backup on' : 'Automatic backup off'} · '
                      '${s.backupCount} backup(s), ${formatFileSize(s.backupBytes)} · documents ${formatFileSize(s.documentBytes)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                      label: const Text('Manage Backups'),
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
