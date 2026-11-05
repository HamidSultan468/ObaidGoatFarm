import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/accounting/accounting_models.dart';
import '../../../../core/accounting/money_format.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/widgets/date_field.dart';

class BudgetsTab extends ConsumerWidget {
  const BudgetsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const _AddBudgetDialog()),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add budget'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: budgetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load budgets.'))),
            data: (budgets) {
              if (budgets.isEmpty) {
                return const Center(child: Text('No budgets yet. Set a spending/income limit per account and period.'));
              }
              return ListView.separated(
                itemCount: budgets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _BudgetCard(budget: budgets[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.budget});
  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(budgetProgressProvider(budget.id));
    final dateFormat = DateFormat.yMMMd();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${budget.account.code} · ${budget.account.name}', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                ),
                Text('${formatMoney(budget.amount)} budgeted', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            Text(
              '${dateFormat.format(budget.periodStart)} – ${dateFormat.format(budget.periodEnd)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            progressAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Could not load progress.'),
              data: (progress) {
                final percent = double.tryParse(progress.percentUsed ?? '') ?? 0;
                final over = percent > 100;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percent / 100).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: over ? scheme.error : scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progress.percentUsed == null
                          ? '${formatMoney(progress.actual)} spent so far'
                          : '${formatMoney(progress.actual)} spent (${progress.percentUsed}%) · ${formatMoney(progress.remaining)} remaining',
                      style: TextStyle(color: over ? scheme.error : null, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBudgetDialog extends ConsumerStatefulWidget {
  const _AddBudgetDialog();

  @override
  ConsumerState<_AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends ConsumerState<_AddBudgetDialog> {
  String? _accountId;
  final _amountController = TextEditingController();
  DateTime? _periodStart;
  DateTime? _periodEnd;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = _amountController.text.trim();
    if (_accountId == null || _periodStart == null || _periodEnd == null || amount.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    if (_periodEnd!.isBefore(_periodStart!)) {
      setState(() => _error = 'The period end must be on or after the start.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(budgetsControllerProvider.notifier).create(accountId: _accountId!, periodStart: _periodStart!, periodEnd: _periodEnd!, amount: amount);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      setState(() {
        _submitting = false;
        _error = apiErrorMessage(error, 'Could not create the budget.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);

    return AlertDialog(
      title: const Text('Add budget'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
            ],
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Could not load accounts.'),
              data: (accounts) => DropdownButtonFormField<String>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  for (final a in accounts.where((a) => a.isActive))
                    DropdownMenuItem(value: a.id, child: Text('${a.code} · ${a.name}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Budgeted amount'),
            ),
            const SizedBox(height: 12),
            DateField(label: 'Period start', value: _periodStart, onChanged: (d) => setState(() => _periodStart = d)),
            const SizedBox(height: 12),
            DateField(label: 'Period end', value: _periodEnd, onChanged: (d) => setState(() => _periodEnd = d)),
          ],
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
