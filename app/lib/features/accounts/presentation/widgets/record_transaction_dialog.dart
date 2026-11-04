import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/accounting/accounting_models.dart';
import '../../../../core/farm/farm_controller.dart';
import '../../../../core/land/land.dart';
import '../../../../core/offline/outbox_controller.dart';
import '../../../../core/offline/outbox_models.dart';

enum TransactionKind { income, expense, transfer }

class RecordTransactionDialog extends ConsumerStatefulWidget {
  const RecordTransactionDialog({super.key, required this.kind});
  final TransactionKind kind;

  @override
  ConsumerState<RecordTransactionDialog> createState() => _RecordTransactionDialogState();
}

class _RecordTransactionDialogState extends ConsumerState<RecordTransactionDialog> {
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  String? _primaryAccountId; // cash/bank side for income+expense, "from" for transfer
  String? _secondaryAccountId; // income/expense category, or "to" for transfer
  String? _animalId; // optional Goat Farm tag (income/expense only)
  String? _landParcelId; // optional Land tag (income/expense only)
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
    TransactionKind.income => 'Record income',
    TransactionKind.expense => 'Record expense',
    TransactionKind.transfer => 'Transfer between accounts',
  };

  Future<void> _submit() async {
    final amount = _amountController.text.trim();
    if (amount.isEmpty || _primaryAccountId == null || _secondaryAccountId == null) {
      setState(() => _errorMessage = 'Fill in all required fields.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final workspaceId = requireWorkspaceIdFromWidget(ref);
    final memo = _memoController.text.trim();
    final (kind, payload, label) = switch (widget.kind) {
      TransactionKind.income => (
        OutboxKind.income,
        {
          'toAccountId': _primaryAccountId,
          'incomeAccountId': _secondaryAccountId,
          'amount': amount,
          'memo': memo.isEmpty ? null : memo,
          'animalId': _animalId,
          'landParcelId': _landParcelId,
        },
        'Income',
      ),
      TransactionKind.expense => (
        OutboxKind.expense,
        {
          'fromAccountId': _primaryAccountId,
          'expenseAccountId': _secondaryAccountId,
          'amount': amount,
          'memo': memo.isEmpty ? null : memo,
          'animalId': _animalId,
          'landParcelId': _landParcelId,
        },
        'Expense',
      ),
      TransactionKind.transfer => (
        OutboxKind.transfer,
        {'fromAccountId': _primaryAccountId, 'toAccountId': _secondaryAccountId, 'amount': amount, 'memo': memo.isEmpty ? null : memo},
        'Transfer',
      ),
    };

    final result = await ref
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: workspaceId, kind: kind, summary: '$label: $amount${memo.isEmpty ? '' : ' — $memo'}', payload: payload, animalId: _animalId);

    if (!mounted) return;
    switch (result) {
      case OutboxSubmitSynced():
        if (_animalId != null) invalidateFarm(ref, animalId: _animalId);
        if (_landParcelId != null) invalidateLand(ref, parcelId: _landParcelId);
        Navigator.of(context).pop();
      case OutboxSubmitQueued():
        // Not yet on the server — the sync-status indicator shows it pending,
        // not this dialog pretending the lists already reflect it.
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No connection — saved and will post automatically once you\'re back online.')),
        );
      case OutboxSubmitRejected(:final message):
        setState(() {
          _isSubmitting = false;
          _errorMessage = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsControllerProvider);

    return AlertDialog(
      title: Text(_title),
      content: accountsAsync.when(
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (error, _) => Text('Could not load accounts: $error'),
        data: (accounts) => _buildForm(accounts),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Post'),
        ),
      ],
    );
  }

  Widget _buildForm(List<Account> accounts) {
    final cashAndBank = accounts.where((a) => a.kind == 'CASH' || a.kind == 'BANK').toList();
    final categoryAccounts = accounts.where((a) => a.type == (widget.kind == TransactionKind.expense ? 'EXPENSE' : 'INCOME')).toList();
    final transferTargets = accounts.where((a) => a.kind == 'CASH' || a.kind == 'BANK' || a.kind == 'GENERAL').toList();

    // Scrollable: with the optional animal/land tags the form is taller than
    // short screens (caught by record_transaction_dialog_test.dart at 800x600).
    return SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            _accountDropdown(
              label: switch (widget.kind) {
                TransactionKind.income => 'Received into',
                TransactionKind.expense => 'Paid from',
                TransactionKind.transfer => 'Transfer from',
              },
              value: _primaryAccountId,
              accounts: cashAndBank,
              onChanged: (value) => setState(() => _primaryAccountId = value),
            ),
            const SizedBox(height: 12),
            _accountDropdown(
              label: widget.kind == TransactionKind.transfer ? 'Transfer to' : 'Category',
              value: _secondaryAccountId,
              accounts: widget.kind == TransactionKind.transfer ? transferTargets : categoryAccounts,
              onChanged: (value) => setState(() => _secondaryAccountId = value),
            ),
            if (widget.kind != TransactionKind.transfer) ...[
              const SizedBox(height: 12),
              _animalDropdown(),
              const SizedBox(height: 12),
              _landDropdown(),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: 'Memo (optional)'),
            ),
          ],
        ),
      ),
    );
  }

  /// Optional per-animal tag so the income/cost shows on that animal's
  /// Finances card. Lists every animal (a sale is often recorded after the
  /// animal is marked sold).
  Widget _animalDropdown() {
    final animals = ref.watch(allAnimalsProvider).value ?? const [];
    return DropdownButtonFormField<String?>(
      initialValue: _animalId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Animal (optional)'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('None')),
        for (final animal in animals)
          DropdownMenuItem<String?>(
            value: animal.id,
            child: Text(animal.ref.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _animalId = value),
    );
  }

  /// Optional per-parcel tag: crop sales, rent, labor, irrigation, fertilizer.
  Widget _landDropdown() {
    final parcels = ref.watch(allLandParcelsProvider).value ?? const [];
    return DropdownButtonFormField<String?>(
      initialValue: _landParcelId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Land (optional)'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('None')),
        for (final parcel in parcels)
          DropdownMenuItem<String?>(
            value: parcel.id,
            child: Text(parcel.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) => setState(() => _landParcelId = value),
    );
  }

  /// `isExpanded` + ellipsis so a long account name truncates instead of
  /// overflowing the field (caught by record_transaction_dialog_test.dart).
  Widget _accountDropdown({
    required String label,
    required String? value,
    required List<Account> accounts,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: accounts
          .map(
            (a) => DropdownMenuItem(
              value: a.id,
              child: Text('${a.code} · ${a.name}', overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
