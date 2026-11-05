import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/accounting/accounting_models.dart';
import '../../../../core/accounting/money_format.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/farm/farm_format.dart' show humanizeEnum;
import '../../../../core/widgets/date_field.dart';

const _frequencies = ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'];
const _entryTypes = ['INCOME', 'EXPENSE', 'TRANSFER'];

class RecurringTemplatesTab extends ConsumerWidget {
  const RecurringTemplatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(recurringTemplatesControllerProvider);
    final accountsAsync = ref.watch(accountsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const _AddTemplateDialog()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add template'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load recurring templates.'))),
            data: (templates) {
              if (templates.isEmpty) {
                return const Center(child: Text('No recurring templates yet — e.g. monthly rent, a recurring salary.'));
              }
              final accountNames = {for (final a in accountsAsync.value ?? const <Account>[]) a.id: '${a.code} · ${a.name}'};
              return ListView.separated(
                itemCount: templates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _TemplateCard(template: templates[index], accountNames: accountNames),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateCard extends ConsumerStatefulWidget {
  const _TemplateCard({required this.template, required this.accountNames});
  final RecurringTemplate template;
  final Map<String, String> accountNames;

  @override
  ConsumerState<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<_TemplateCard> {
  bool _busy = false;

  Future<void> _run() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final entry = await ref.read(recurringTemplatesControllerProvider.notifier).runNow(widget.template.id);
      messenger.showSnackBar(SnackBar(content: Text('Posted ${formatMoney(entry.displayAmount)}.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not run this template.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleActive(bool value) async {
    setState(() => _busy = true);
    try {
      await ref.read(recurringTemplatesControllerProvider.notifier).setActive(widget.template.id, value);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not update this template.'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final dateFormat = DateFormat.yMMMd();
    final from = widget.accountNames[t.fromAccountId] ?? t.fromAccountId;
    final to = widget.accountNames[t.toAccountId] ?? t.toAccountId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(t.name, style: Theme.of(context).textTheme.titleMedium)),
                      Text(formatMoney(t.amount), style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('$from → $to', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${humanizeEnum(t.frequency)} · next run ${dateFormat.format(t.nextRunDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Switch(value: t.isActive, onChanged: _busy ? null : _toggleActive),
                TextButton(
                  onPressed: (_busy || !t.isActive) ? null : _run,
                  child: _busy ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Run now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTemplateDialog extends ConsumerStatefulWidget {
  const _AddTemplateDialog();

  @override
  ConsumerState<_AddTemplateDialog> createState() => _AddTemplateDialogState();
}

class _AddTemplateDialogState extends ConsumerState<_AddTemplateDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _entryType = 'EXPENSE';
  String _frequency = 'MONTHLY';
  String? _fromAccountId;
  String? _toAccountId;
  DateTime? _nextRunDate;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final amount = _amountController.text.trim();
    if (name.isEmpty || amount.isEmpty || _fromAccountId == null || _toAccountId == null || _nextRunDate == null) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (_fromAccountId == _toAccountId) {
      setState(() => _error = 'The two accounts must be different.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(recurringTemplatesControllerProvider.notifier)
          .create(
            name: name,
            entryType: _entryType,
            fromAccountId: _fromAccountId!,
            toAccountId: _toAccountId!,
            amount: amount,
            frequency: _frequency,
            nextRunDate: _nextRunDate!,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() {
        _submitting = false;
        _error = apiErrorMessage(error, 'Could not create the template.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);

    return AlertDialog(
      title: const Text('Add recurring template'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 8),
              ],
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name (e.g. "Monthly rent")')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _entryType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [for (final v in _entryTypes) DropdownMenuItem(value: v, child: Text(humanizeEnum(v)))],
                onChanged: (value) => setState(() => _entryType = value ?? _entryType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Could not load accounts.'),
                data: (accounts) {
                  final active = accounts.where((a) => a.isActive).toList();
                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _fromAccountId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'From account'),
                        items: [for (final a in active) DropdownMenuItem(value: a.id, child: Text('${a.code} · ${a.name}', overflow: TextOverflow.ellipsis))],
                        onChanged: (value) => setState(() => _fromAccountId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _toAccountId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'To account'),
                        items: [for (final a in active) DropdownMenuItem(value: a.id, child: Text('${a.code} · ${a.name}', overflow: TextOverflow.ellipsis))],
                        onChanged: (value) => setState(() => _toAccountId = value),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: [for (final f in _frequencies) DropdownMenuItem(value: f, child: Text(humanizeEnum(f)))],
                onChanged: (value) => setState(() => _frequency = value ?? _frequency),
              ),
              const SizedBox(height: 12),
              DateField(label: 'Next run date', value: _nextRunDate, onChanged: (d) => setState(() => _nextRunDate = d)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add'),
        ),
      ],
    );
  }
}
