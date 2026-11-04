import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
            tabs: const [Tab(text: 'Workspaces'), Tab(text: 'Users')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_WorkspacesTab(), _UsersTab()],
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
            return ListTile(
              leading: const Icon(Icons.business_rounded),
              title: Text(workspace.name),
              subtitle: Text('${workspace.slug} · ${workspace.memberCount} member(s)'),
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
            return ListTile(
              leading: CircleAvatar(child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?')),
              title: Text(user.fullName),
              subtitle: Text('${user.email} · ${user.globalRole}${user.mfaEnabled ? ' · MFA on' : ''}'),
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

String _describe(Object error) => error is DioException ? (error.response?.data?['message'] ?? error.message).toString() : error.toString();

void _showError(BuildContext context, DioException error) {
  final message = error.response?.data is Map && (error.response?.data as Map)['message'] is String
      ? (error.response!.data as Map)['message'] as String
      : 'Action failed.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
