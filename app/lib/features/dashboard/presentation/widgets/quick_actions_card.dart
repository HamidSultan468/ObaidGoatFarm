import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/workspace/workspace_controller.dart';

/// Only one quick action is real today — inviting a member to the current
/// workspace, backed by POST /workspaces/:id/members. The reference mockup
/// shows several more (New Receipt, Scan Receipt, Backup Now, ...) but none
/// of those modules exist yet, so they are deliberately not shown here
/// rather than added as non-functional buttons.
class QuickActionsCard extends ConsumerWidget {
  const QuickActionsCard({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            OutlinedButton.icon(
              onPressed: () => _showInviteDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Invite member'),
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
                            .inviteMember(workspaceId: workspaceId, email: emailController.text.trim(), role: role);
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
