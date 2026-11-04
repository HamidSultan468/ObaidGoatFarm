import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accounting/accounting_controller.dart';
import '../../../core/api/api_error.dart';
import '../../../core/farm/farm_format.dart';
import '../../../core/notifications/notifications.dart';
import '../../../core/widgets/form_dialog.dart';
import '../../../core/workspace/workspace_controller.dart';
import '../../../core/workspace/workspace_models.dart';
import 'widgets/notification_bell.dart';

const _assignableRoles = ['OWNER', 'ADMIN', 'MANAGER', 'STAFF', 'PAYABLE', 'GENERAL'];

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workspaceControllerProvider);
    final canManage = state is WorkspaceSelected && state.workspace.canManage;
    final tabs = [const Tab(text: 'Inbox'), if (canManage) ...[const Tab(text: 'Automatic rules'), const Tab(text: 'Delivery log')]];
    return DefaultTabController(
      length: tabs.length,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Notifications', style: Theme.of(context).textTheme.headlineSmall),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => showDialog<bool>(context: context, builder: (_) => const _SendDialog()),
                    icon: const Icon(Icons.campaign_rounded),
                    label: const Text('Send notification'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: tabs),
            Expanded(
              child: TabBarView(children: [const _InboxTab(), if (canManage) ...[const _RulesTab(), const _DeliveryTab()]]),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxTab extends ConsumerStatefulWidget {
  const _InboxTab();

  @override
  ConsumerState<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends ConsumerState<_InboxTab> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationListProvider(_unreadOnly));
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<bool>(
              segments: const [ButtonSegment(value: false, label: Text('All')), ButtonSegment(value: true, label: Text('Unread'))],
              selected: {_unreadOnly},
              onSelectionChanged: (s) => setState(() => _unreadOnly = s.first),
            ),
            TextButton.icon(
              onPressed: () async {
                await ref.read(notificationsRepositoryProvider).markAllRead(requireWorkspaceIdFromWidget(ref));
                refreshNotifications(ref);
              },
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Mark all read'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load notifications.'))),
            data: (items) => items.isEmpty
                ? Center(child: Text(_unreadOnly ? 'No unread notifications.' : 'No notifications yet.'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = items[index];
                      return ListTile(
                        leading: severityIcon(n.severity, scheme),
                        title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600)),
                        subtitle: Text('${n.body}\n${categoryLabel(n.category)} · ${timeAgo(n.createdAt, now)}'),
                        isThreeLine: true,
                        trailing: n.isRead ? null : Icon(Icons.circle, size: 10, color: scheme.primary),
                        onTap: () => openNotification(context, ref, n),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _RulesTab extends ConsumerStatefulWidget {
  const _RulesTab();

  @override
  ConsumerState<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends ConsumerState<_RulesTab> {
  List<NotificationRule>? _draft;
  bool _saving = false;

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(notificationsRepositoryProvider).saveRules(requireWorkspaceIdFromWidget(ref), _draft!);
      ref.invalidate(notificationRulesProvider);
      setState(() => _draft = null);
      messenger.showSnackBar(const SnackBar(content: Text('Rules saved.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not save the rules.'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runNow() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref.read(notificationsRepositoryProvider).runRules(requireWorkspaceIdFromWidget(ref));
      refreshNotifications(ref);
      messenger.showSnackBar(SnackBar(content: Text(created == 0 ? 'No new reminders.' : 'Sent $created new reminder(s).')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not run the rules.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(notificationRulesProvider);
    return rules.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load the rules.'))),
      data: (saved) {
        final current = _draft ?? saved;
        return ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          children: [
            Text(
              'Reminders are checked every 10 minutes. Each person gets a reminder once; they choose email or in-app in Settings.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final (index, rule) in current.indexed)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(categoryLabel(rule.category)),
                        value: rule.isEnabled,
                        onChanged: (v) => setState(() => _draft = [...current]..[index] = rule.copyWith(isEnabled: v)),
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final role in _assignableRoles)
                            FilterChip(
                              label: Text(humanizeEnum(role)),
                              selected: rule.recipientRoles.contains(role),
                              onSelected: rule.isEnabled
                                  ? (on) => setState(() {
                                      final roles = on ? [...rule.recipientRoles, role] : rule.recipientRoles.where((r) => r != role).toList();
                                      _draft = [...current]..[index] = rule.copyWith(recipientRoles: roles);
                                    })
                                  : null,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(onPressed: _draft == null || _saving ? null : _save, child: const Text('Save rules')),
                OutlinedButton.icon(onPressed: _runNow, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Check now')),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DeliveryTab extends ConsumerWidget {
  const _DeliveryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(deliveryLogProvider);
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: () => ref.refresh(deliveryLogProvider.future),
      child: log.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load the delivery log.'))),
        data: (entries) => entries.isEmpty
            ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('No emails sent yet.'))])
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = entries[index];
                  return ListTile(
                    leading: Icon(switch (e.status) {
                      'SENT' => Icons.mark_email_read_rounded,
                      'FAILED' => Icons.error_outline_rounded,
                      'SKIPPED' => Icons.block_rounded,
                      _ => Icons.schedule_send_rounded,
                    }),
                    title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text([
                      'Email to ${e.recipient}',
                      '${humanizeEnum(e.status)} · ${e.attempts} attempt(s) · ${timeAgo(e.createdAt, now)}',
                      if (e.lastError != null) 'Last error: ${e.lastError}',
                    ].join('\n')),
                    isThreeLine: true,
                  );
                },
              ),
      ),
    );
  }
}

class _SendDialog extends ConsumerStatefulWidget {
  const _SendDialog();

  @override
  ConsumerState<_SendDialog> createState() => _SendDialogState();
}

class _SendDialogState extends ConsumerState<_SendDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final Set<String> _roles = {'OWNER', 'ADMIN', 'MANAGER', 'STAFF'};
  String _severity = 'INFO';

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Send notification',
      submitLabel: 'Send',
      fallbackError: 'Could not send the notification.',
      validate: () {
        if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return 'Enter a title and a message.';
        if (_roles.isEmpty) return 'Choose at least one role.';
        return null;
      },
      onSubmit: () async {
        final messenger = ScaffoldMessenger.of(context);
        final count = await ref.read(notificationsRepositoryProvider).send(
          requireWorkspaceIdFromWidget(ref),
          title: _title.text.trim(),
          body: _body.text.trim(),
          severity: _severity,
          roles: _roles.toList(),
        );
        refreshNotifications(ref);
        messenger.showSnackBar(SnackBar(content: Text('Sent to $count member(s).')));
      },
      children: [
        TextField(controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: 'Title *')),
        TextField(controller: _body, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(labelText: 'Message *')),
        DropdownButtonFormField<String>(
          initialValue: _severity,
          decoration: const InputDecoration(labelText: 'Importance'),
          items: const [
            DropdownMenuItem(value: 'INFO', child: Text('Normal')),
            DropdownMenuItem(value: 'WARNING', child: Text('Important')),
            DropdownMenuItem(value: 'CRITICAL', child: Text('Urgent')),
          ],
          onChanged: (v) => setState(() => _severity = v ?? _severity),
        ),
        Text('Send to', style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final role in _assignableRoles)
              FilterChip(
                label: Text(humanizeEnum(role)),
                selected: _roles.contains(role),
                onSelected: (on) => setState(() => on ? _roles.add(role) : _roles.remove(role)),
              ),
          ],
        ),
      ],
    );
  }
}
