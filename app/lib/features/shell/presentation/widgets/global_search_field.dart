import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/workspace/workspace_controller.dart';
import '../../../../core/workspace/workspace_models.dart';
import '../sidebar_nav.dart';

sealed class _SearchResult {
  const _SearchResult();
  String get label;
  IconData get icon;
}

class _NavResult extends _SearchResult {
  const _NavResult(this.item, this.resolvedLabel);
  final SidebarNavItem item;
  final String resolvedLabel;
  @override
  String get label => resolvedLabel;
  @override
  IconData get icon => item.icon;
}

class _WorkspaceResult extends _SearchResult {
  const _WorkspaceResult(this.workspace);
  final Workspace workspace;
  @override
  String get label => '${workspace.name} (workspace)';
  @override
  IconData get icon => Icons.business_rounded;
}

/// Searches real, currently-available data only: sidebar destinations (so
/// typing a module name jumps straight to it) and the caller's workspaces.
/// There is nothing else searchable yet — no fabricated results.
class GlobalSearchField extends ConsumerWidget {
  const GlobalSearchField({super.key, required this.showAdminConsole});

  final bool showAdminConsole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceState = ref.watch(workspaceControllerProvider);
    final workspaces = workspaceState is WorkspaceSelected ? workspaceState.all : const <Workspace>[];
    final navItems = [...sidebarNavItems, if (showAdminConsole) adminConsoleNavItem];
    // Resolved once against this widget's own (stable) context — Autocomplete's
    // own callbacks don't receive a BuildContext, so labels are localized here.
    final navResults = navItems.map((item) => _NavResult(item, item.label(context))).toList();

    return Autocomplete<_SearchResult>(
      displayStringForOption: (result) => result.label,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<_SearchResult>.empty();

        return [
          ...navResults.where((result) => result.label.toLowerCase().contains(query)),
          ...workspaces.where((ws) => ws.name.toLowerCase().contains(query)).map(_WorkspaceResult.new),
        ];
      },
      onSelected: (result) {
        switch (result) {
          case _NavResult(:final item):
            context.go(item.route);
          case _WorkspaceResult(:final workspace):
            ref.read(workspaceControllerProvider.notifier).select(workspace);
        }
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            filled: true,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, minWidth: 320),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: options
                    .map(
                      (result) => ListTile(
                        leading: Icon(result.icon),
                        title: Text(result.label),
                        onTap: () => onSelected(result),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
