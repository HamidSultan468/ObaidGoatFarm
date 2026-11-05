import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/admin/admin_controller.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Console', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Platform-wide administration. Changing status or roles requires the Super Admin Owner role with MFA enabled.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [Tab(text: 'Workspaces'), Tab(text: 'Users'), Tab(text: 'System Logs')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_WorkspacesTab(), _UsersTab(), _SystemLogsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspacesTab extends ConsumerWidget {
  const _WorkspacesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(adminWorkspacesControllerProvider);

    return workspacesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load workspaces: ${_describe(error)}')),
      data: (workspaces) {
        if (workspaces.isEmpty) {
          return const Center(child: Text('No workspaces exist yet.'));
        }
        return ListView.separated(
          itemCount: workspaces.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final workspace = workspaces[index];
            final roles = workspace.roleBreakdown.entries.map((e) => '${e.value} ${e.key.toLowerCase()}').join(', ');
            return ListTile(
              leading: const Icon(Icons.business_rounded),
              title: Text(workspace.name),
              subtitle: Text(
                [
                  '${workspace.slug} · ${workspace.memberCount} member(s)${roles.isNotEmpty ? ' ($roles)' : ''}',
                  if (workspace.ownerEmail != null) 'Owner: ${workspace.ownerName ?? workspace.ownerEmail}',
                  'Created ${DateFormat('d MMM yyyy').format(workspace.createdAt)} · '
                      '${workspace.animalCount} animal(s) · ${workspace.landParcelCount} parcel(s) · ${workspace.transactionCount} transaction(s)',
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: Switch(
                value: workspace.isActive,
                onChanged: (value) async {
                  try {
                    await ref.read(adminWorkspacesControllerProvider.notifier).setActive(workspace.id, value);
                  } on DioException catch (error) {
                    if (context.mounted) _showError(context, error);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersControllerProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load users: ${_describe(error)}')),
      data: (users) {
        return ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            final workspaceList = user.workspaces.isEmpty
                ? 'No workspaces'
                : user.workspaces.map((w) => '${w.name} (${w.role.toLowerCase()})').join(', ');
            return ListTile(
              leading: CircleAvatar(child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?')),
              title: Text(user.fullName),
              subtitle: Text(
                [
                  '${user.email} · ${user.globalRole}${user.mfaEnabled ? ' · MFA on' : ''} · ${user.preferredLanguage.toUpperCase()}',
                  'Joined ${DateFormat('d MMM yyyy').format(user.createdAt)}'
                      '${user.lastLoginAt != null ? ' · Last login ${DateFormat('d MMM, HH:mm').format(user.lastLoginAt!)}' : ' · Never logged in'}',
                  workspaceList,
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: user.globalRole == 'SUPER_ADMIN_OWNER'
                  ? const Tooltip(message: 'The owner account cannot be modified here', child: Icon(Icons.lock_outline))
                  : Switch(
                      value: user.isActive,
                      onChanged: (value) async {
                        try {
                          await ref.read(adminUsersControllerProvider.notifier).setActive(user.id, value);
                        } on DioException catch (error) {
                          if (context.mounted) _showError(context, error);
                        }
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

class _SystemLogsTab extends ConsumerStatefulWidget {
  const _SystemLogsTab();

  @override
  ConsumerState<_SystemLogsTab> createState() => _SystemLogsTabState();
}

class _SystemLogsTabState extends ConsumerState<_SystemLogsTab> {
  final _actionController = TextEditingController();

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(systemLogsProvider);
    final dateFormat = DateFormat('d MMM, HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _actionController,
                  decoration: const InputDecoration(labelText: 'Filter by action (e.g. "admin.", "report.export")', isDense: true),
                  onSubmitted: (value) => ref.read(systemLogActionFilterProvider.notifier).set(value),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Apply filter',
                icon: const Icon(Icons.search_rounded),
                onPressed: () => ref.read(systemLogActionFilterProvider.notifier).set(_actionController.text),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => ref.invalidate(systemLogsProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Could not load the system log: ${_describe(error)}')),
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text('No log entries match.'));
              }
              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long_rounded, size: 20),
                    title: Text(log.action, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                    subtitle: Text(
                      '${log.entityType}${log.entityId != null ? ' · ${log.entityId}' : ''} · '
                      '${log.workspaceName ?? 'platform-level'} · ${log.actorEmail ?? 'system'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(dateFormat.format(log.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

String _describe(Object error) => error is DioException ? (error.response?.data?['message'] ?? error.message).toString() : error.toString();

void _showError(BuildContext context, DioException error) {
  final message = error.response?.data is Map && (error.response?.data as Map)['message'] is String
      ? (error.response!.data as Map)['message'] as String
      : 'Action failed.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
