import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/backup/backup.dart';
import '../../../../core/documents/documents.dart';
import '../../../../core/farm/farm_format.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/workspace/workspace_controller.dart';
import '../../../../core/workspace/workspace_models.dart';

/// Backup & restore for OWNER/ADMIN. Restoring always creates a new
/// workspace; the current one is never overwritten.
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key, required this.isOwner});
  final bool isOwner;

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Something went wrong. Please try again.'))));
    } finally {
      refreshBackups(ref);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _afterRestore(Workspace restored) async {
    refreshNotifications(ref);
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup restored'),
        content: Text('"${restored.name}" was created. Your current workspace was not changed.\n\nOpen the restored workspace now?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Stay here')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Open it')),
        ],
      ),
    );
    if (open == true) {
      await ref.read(workspaceControllerProvider.notifier).reloadAndSelect(restored.id);
      if (mounted) context.go('/dashboard');
    } else {
      final current = ref.read(workspaceControllerProvider);
      if (current is WorkspaceSelected) await ref.read(workspaceControllerProvider.notifier).reloadAndSelect(current.workspace.id);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(action)),
            ],
          ),
        ) ==
        true;
  }

  Future<void> _onAction(String action, BackupItem b) async {
    final repo = ref.read(backupRepositoryProvider);
    final ws = requireWorkspaceIdFromWidget(ref);
    switch (action) {
      case 'verify':
        await _run(() async {
          final result = await repo.verify(ws, b.id);
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              icon: Icon(result.valid ? Icons.verified_rounded : Icons.error_rounded, color: result.valid ? Colors.green : Colors.red),
              title: Text(result.valid ? 'Backup is valid' : 'Backup failed verification'),
              content: Text(result.valid ? 'The file is intact, unmodified, and every transaction balances. It can be restored.' : result.errors.join('\n')),
              actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK'))],
            ),
          );
        });
      case 'download':
        await _run(() async {
          final bytes = await repo.download(ws, b.id);
          final day = b.startedAt.toIso8601String().substring(0, 10);
          await FilePicker.saveFile(fileName: 'tangent-backup-$day.tsmbak', bytes: bytes, mimeType: 'application/octet-stream');
        });
      case 'restore':
        if (!await _confirm(
          'Restore this backup?',
          'The backup is verified first, then restored into a NEW workspace. Your current workspace stays exactly as it is.',
          'Restore',
        )) {
          return;
        }
        await _run(() async {
          final restored = await repo.restore(ws, b.id);
          await _afterRestore(restored);
        });
      case 'delete':
        if (!await _confirm('Delete this backup?', 'The backup file will be permanently deleted.', 'Delete')) return;
        await _run(() => repo.delete(ws, b.id), success: 'Backup deleted.');
    }
  }

  Future<void> _restoreFromFile() async {
    final picked = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['tsmbak']);
    if (picked == null) return;
    await _run(() async {
      final restored = await ref.read(backupRepositoryProvider).restoreFromFile(await picked.readAsBytes(), picked.name);
      await _afterRestore(restored);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(backupStatusProvider);
    final backups = ref.watch(backupListProvider);
    final now = DateTime.now();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Backup & restore', style: Theme.of(context).textTheme.titleMedium)),
                if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Encrypted backups of all records and documents in this workspace, stored on this server.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            status.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(apiErrorMessage(error, 'Could not load backup status.')),
              data: (s) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.lastSuccessfulBackup == null
                        ? 'No backup yet.'
                        : 'Last successful backup: ${timeAgo(s.lastSuccessfulBackup!.startedAt, now)} · ${s.backupCount} backup(s), ${formatFileSize(s.backupBytes)}',
                  ),
                  if (s.lastBackup != null && s.lastBackup!.status == 'FAILED')
                    Text('Latest backup failed: ${s.lastBackup!.error ?? ''}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Automatic daily backup (02:00)'),
                    subtitle: Text('Keeps the last ${s.retention} automatic backups. Manual backups are kept until you delete them.'),
                    value: s.autoBackupEnabled,
                    onChanged: _busy
                        ? null
                        : (v) => _run(() => ref.read(backupRepositoryProvider).updateSettings(requireWorkspaceIdFromWidget(ref), autoBackupEnabled: v)),
                  ),
                  Row(
                    children: [
                      const Text('Automatic backups to keep: '),
                      DropdownButton<int>(
                        value: s.retention,
                        items: [for (final n in {1, 3, 7, 14, 30, s.retention}.toList()..sort()) DropdownMenuItem(value: n, child: Text('$n'))],
                        onChanged: _busy
                            ? null
                            : (v) => _run(() => ref.read(backupRepositoryProvider).updateSettings(requireWorkspaceIdFromWidget(ref), retention: v)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref.read(backupRepositoryProvider).create(requireWorkspaceIdFromWidget(ref)), success: 'Backup completed.'),
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('Back up now'),
                ),
                if (widget.isOwner)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreFromFile,
                    icon: const Icon(Icons.settings_backup_restore_rounded),
                    label: const Text('Restore from file'),
                  ),
              ],
            ),
            const Divider(height: 24),
            backups.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Text(apiErrorMessage(error, 'Could not load backups.')),
              data: (list) => list.isEmpty
                  ? const Text('No backups yet.')
                  : Column(
                      children: [
                        for (final b in list.take(10))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(b.isCompleted ? Icons.cloud_done_rounded : (b.status == 'FAILED' ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded)),
                            title: Text('${formatDate(b.startedAt)} · ${humanizeEnum(b.trigger)}${b.sizeBytes != null ? ' · ${formatFileSize(b.sizeBytes!)}' : ''}'),
                            subtitle: Text(b.isCompleted ? b.summary : (b.error ?? humanizeEnum(b.status))),
                            trailing: !b.isCompleted
                                ? null
                                : PopupMenuButton<String>(
                                    tooltip: 'Backup actions',
                                    enabled: !_busy,
                                    onSelected: (action) => _onAction(action, b),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: 'verify', child: Text('Verify')),
                                      const PopupMenuItem(value: 'download', child: Text('Download')),
                                      if (widget.isOwner) const PopupMenuItem(value: 'restore', child: Text('Restore to a new workspace')),
                                      if (widget.isOwner) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
