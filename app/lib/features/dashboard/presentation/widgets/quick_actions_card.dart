import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/backup/backup.dart';
import '../../../../core/workspace/workspace_controller.dart';
import '../../../accounts/presentation/widgets/record_transaction_dialog.dart';

/// Quick-action tiles on the dashboard. Every tile is backed by a real,
/// already-built feature — the reference mockup also shows a calculator
/// and a voice-command tile, neither of which exists anywhere in this app
/// (no calculator feature, voice notes are explicitly not built — see
/// AI_AUTOMATION.md), so they are deliberately left out rather than added
/// as non-functional buttons.
class QuickActionsCard extends ConsumerStatefulWidget {
  const QuickActionsCard({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<QuickActionsCard> createState() => _QuickActionsCardState();
}

class _QuickActionsCardState extends ConsumerState<QuickActionsCard> {
  bool _backingUp = false;

  Future<void> _backUpNow() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _backingUp = true);
    try {
      await ref.read(backupRepositoryProvider).create(widget.workspaceId);
      refreshBackups(ref);
      messenger.showSnackBar(const SnackBar(content: Text('Backup completed.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not back up right now.'))));
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _QuickAction(
        icon: Icons.arrow_downward_rounded,
        color: const Color(0xFF22A559),
        label: 'New Income',
        onTap: () => showDialog<void>(context: context, builder: (_) => const RecordTransactionDialog(kind: TransactionKind.income)),
      ),
      _QuickAction(
        icon: Icons.arrow_upward_rounded,
        color: const Color(0xFFE5484D),
        label: 'New Expense',
        onTap: () => showDialog<void>(context: context, builder: (_) => const RecordTransactionDialog(kind: TransactionKind.expense)),
      ),
      _QuickAction(
        icon: Icons.document_scanner_rounded,
        color: const Color(0xFF8B5CF6),
        label: 'Scan Receipt',
        onTap: () => context.go('/ai-assistant'),
      ),
      _QuickAction(icon: Icons.insights_rounded, color: const Color(0xFF3B82F6), label: 'Reports', onTap: () => context.go('/reports')),
      _QuickAction(
        icon: Icons.person_add_alt_rounded,
        color: const Color(0xFFF59E0B),
        label: 'Invite Member',
        onTap: () => _showInviteDialog(context, ref),
      ),
      _QuickAction(
        icon: Icons.cloud_upload_rounded,
        color: const Color(0xFF2F6FED),
        label: 'Backup Now',
        onTap: _backingUp ? null : _backUpNow,
        busy: _backingUp,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: tiles,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    var role = 'STAFF';
    String? errorMessage;
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Invite a member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorMessage != null) ...[
                Text(errorMessage!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                  DropdownMenuItem(value: 'STAFF', child: Text('Staff')),
                  DropdownMenuItem(value: 'VIEWER', child: Text('Viewer')),
                ],
                onChanged: (value) => setState(() => role = value ?? role),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setState(() => isSubmitting = true);
                      try {
                        await ref
                            .read(workspaceRepositoryProvider)
                            .inviteMember(workspaceId: widget.workspaceId, email: emailController.text.trim(), role: role);
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      } on DioException catch (error) {
                        final data = error.response?.data;
                        setState(() {
                          isSubmitting = false;
                          errorMessage = data is Map && data['message'] is String
                              ? data['message'] as String
                              : 'Could not send the invite.';
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Invite'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.color, required this.label, required this.onTap, this.busy = false});

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              busy
                  ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
