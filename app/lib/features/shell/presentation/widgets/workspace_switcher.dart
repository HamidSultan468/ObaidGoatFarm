import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/farm/farm_format.dart';
import '../../../../core/workspace/workspace_controller.dart';
import '../../../../core/workspace/workspace_models.dart';

/// Lets a member of several workspaces switch between them. Hidden when
/// there is only one. Switching returns to the dashboard, because detail
/// pages (an animal, a land parcel) belong to the previous workspace.
class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({super.key, this.compact = false});

  /// Icon only, for narrow (phone) layouts.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    if (state is! WorkspaceSelected || state.all.length < 2) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Switch workspace',
      onSelected: (id) {
        ref.read(workspaceControllerProvider.notifier).select(state.all.firstWhere((w) => w.id == id));
        context.go('/dashboard');
      },
      itemBuilder: (_) => [
        for (final w in state.all)
          PopupMenuItem(
            value: w.id,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(w.id == state.workspace.id ? Icons.check_rounded : Icons.business_rounded),
              title: Text(w.name, overflow: TextOverflow.ellipsis),
              subtitle: w.myRole == null ? null : Text(humanizeEnum(w.myRole!)),
            ),
          ),
      ],
      child: compact
          ? const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.swap_horiz_rounded))
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Chip(
                avatar: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(state.workspace.name, overflow: TextOverflow.ellipsis),
              ),
            ),
    );
  }
}
