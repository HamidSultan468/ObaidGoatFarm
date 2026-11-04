import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/ai/ai.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/widgets/form_dialog.dart';

/// AI provider keys (write-only), failover order, monthly limits, usage.
class AiSettingsSection extends ConsumerStatefulWidget {
  const AiSettingsSection({super.key});

  @override
  ConsumerState<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<AiSettingsSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (success != null) messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Something went wrong.'))));
    } finally {
      ref.invalidate(aiProvidersProvider);
      ref.invalidate(aiUsageProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(aiProvidersProvider);
    final usage = ref.watch(aiUsageProvider).value ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('AI assistant', style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(
                  onPressed: _busy ? null : () => showDialog<bool>(context: context, builder: (_) => const _AddProviderDialog()).then((_) => ref.invalidate(aiProvidersProvider)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add API key'),
                ),
              ],
            ),
            Text(
              'Keys are stored encrypted and never shown again. If one provider fails, the next is tried. AI only prepares drafts; people approve them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            providers.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(apiErrorMessage(error, 'Could not load AI settings.')),
              data: (list) => list.isEmpty
                  ? const Text('Not set up. Manual entry works without AI.')
                  : Column(
                      children: [
                        for (final p in list)
                          Builder(
                            builder: (context) {
                              final u = usage.where((x) => x.configId == p.id).firstOrNull;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(child: Text('${p.priority}')),
                                title: Text('${aiModelChoices[p.model] ?? p.model} · key …${p.keyHint}'),
                                subtitle: Text([
                                  if (u != null) 'This month: ${u.requests} request(s), ${u.failures} failed, ${u.inputTokens + u.outputTokens} tokens',
                                  if (p.monthlyRequestLimit != null) 'Limit ${p.monthlyRequestLimit}/month',
                                ].join(' · ')),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: p.isEnabled,
                                      onChanged: _busy ? null : (v) => _run(() => ref.read(aiRepositoryProvider).updateProvider(requireWorkspaceIdFromWidget(ref), p.id, {'isEnabled': v})),
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: !_busy,
                                      onSelected: (action) async {
                                        final repo = ref.read(aiRepositoryProvider);
                                        final ws = requireWorkspaceIdFromWidget(ref);
                                        if (action == 'test') {
                                          await _run(() async {
                                            final (ok, message) = await repo.testProvider(ws, p.id);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? '✓ $message' : 'Failed: $message')));
                                            }
                                          });
                                        } else if (action == 'delete') {
                                          await _run(() => repo.removeProvider(ws, p.id), success: 'API key removed.');
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'test', child: Text('Test connection')),
                                        PopupMenuItem(value: 'delete', child: Text('Remove')),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
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

class _AddProviderDialog extends ConsumerStatefulWidget {
  const _AddProviderDialog();

  @override
  ConsumerState<_AddProviderDialog> createState() => _AddProviderDialogState();
}

class _AddProviderDialogState extends ConsumerState<_AddProviderDialog> {
  final _key = TextEditingController();
  final _limit = TextEditingController();
  String _model = aiModelChoices.keys.first;
  int _priority = 1;

  @override
  void dispose() {
    _key.dispose();
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Add Anthropic API key',
      submitLabel: 'Save',
      fallbackError: 'Could not save the API key.',
      validate: () {
        if (_key.text.trim().length < 20) return 'Paste the full API key.';
        if (_limit.text.trim().isNotEmpty && (int.tryParse(_limit.text.trim()) ?? 0) < 1) return 'The monthly limit must be a whole number above 0.';
        return null;
      },
      onSubmit: () => ref.read(aiRepositoryProvider).addProvider(
        requireWorkspaceIdFromWidget(ref),
        apiKey: _key.text.trim(),
        model: _model,
        priority: _priority,
        monthlyRequestLimit: _limit.text.trim().isEmpty ? null : int.parse(_limit.text.trim()),
      ),
      children: [
        TextField(controller: _key, obscureText: true, decoration: const InputDecoration(labelText: 'API key (sk-ant-…)')),
        DropdownButtonFormField<String>(
          initialValue: _model,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Model'),
          items: [for (final e in aiModelChoices.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _model = v ?? _model),
        ),
        DropdownButtonFormField<int>(
          initialValue: _priority,
          decoration: const InputDecoration(labelText: 'Order (1 is tried first)'),
          items: [for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i'))],
          onChanged: (v) => setState(() => _priority = v ?? _priority),
        ),
        TextField(controller: _limit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly request limit (optional)')),
      ],
    );
  }
}
