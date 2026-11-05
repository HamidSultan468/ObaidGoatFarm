import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/farm/farm_format.dart';
import '../../../core/workspace/workspace_controller.dart';
import '../../../core/workspace/workspace_models.dart';

const _assignableRoles = ['ADMIN', 'MANAGER', 'STAFF', 'VIEWER'];

/// The people who have access to this workspace: their role, when they
/// joined, and — for OWNER/ADMIN callers — controls to change a role or
/// remove access. Everyone else sees the same list read-only.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(workspaceControllerProvider);
    if (workspaceState is! WorkspaceSelected) {
      return const Center(child: CircularProgressIndicator());
    }
    final workspace = workspaceState.workspace;
    final members = ref.watch(workspaceMembersProvider(workspace.id));
    final authState = ref.watch(authControllerProvider);
    final myUserId = authState is AuthAuthenticated ? authState.profile.id : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Staff', style: Theme.of(context).textTheme.headlineSmall)),
              if (workspace.canManage)
                FilledButton.icon(
                  onPressed: () => _showInviteDialog(context, ref, workspace.id),
                  icon: const Icon(Icons.person_add_alt_rounded),
                  label: const Text('Invite member'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Everyone with access to "${workspace.name}", and the role each one holds.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: members.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load staff.'))),
              data: (list) => ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = list[index];
                  final isSelf = member.userId == myUserId;
                  final isOwner = member.role == 'OWNER';
                  return _MemberTile(
                    workspaceId: workspace.id,
                    member: member,
                    canManage: workspace.canManage && !isSelf && !isOwner,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref, String workspaceId) async {
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
                items: [for (final r in _assignableRoles) DropdownMenuItem(value: r, child: Text(humanizeEnum(r)))],
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
                        ref.invalidate(workspaceMembersProvider(workspaceId));
                        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                      } catch (error) {
                        setState(() {
                          isSubmitting = false;
                          errorMessage = apiErrorMessage(error, 'Could not send the invite.');
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

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.workspaceId, required this.member, required this.canManage});

  final String workspaceId;
  final WorkspaceMember member;
  final bool canManage;

  Future<void> _changeRole(BuildContext context, WidgetRef ref, String role) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(workspaceRepositoryProvider).setMemberRole(workspaceId: workspaceId, membershipId: member.id, role: role);
      ref.invalidate(workspaceMembersProvider(workspaceId));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not change this member\'s role.'))));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this member?'),
        content: Text('${member.displayName} will lose access to this workspace. Their past activity stays on record.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(workspaceRepositoryProvider).removeMember(workspaceId: workspaceId, membershipId: member.id);
      ref.invalidate(workspaceMembersProvider(workspaceId));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not remove this member.'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joined = member.acceptedAt ?? member.invitedAt;
    return ListTile(
      leading: CircleAvatar(child: Text(member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?')),
      title: Text(member.displayName),
      subtitle: Text([
        member.email,
        'Joined ${formatDate(joined)}',
        if (member.lastLoginAt != null) 'Last active ${formatDate(member.lastLoginAt!)}',
      ].join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Change role',
              onSelected: (role) => _changeRole(context, ref, role),
              itemBuilder: (_) => [for (final r in _assignableRoles) PopupMenuItem(value: r, child: Text(humanizeEnum(r)))],
              child: Chip(avatar: const Icon(Icons.edit_rounded, size: 16), label: Text(humanizeEnum(member.role))),
            )
          else
            Chip(label: Text(humanizeEnum(member.role))),
          if (canManage)
            IconButton(
              tooltip: 'Remove from workspace',
              icon: const Icon(Icons.person_remove_rounded),
              onPressed: () => _remove(context, ref),
            ),
        ],
      ),
    );
  }
}
