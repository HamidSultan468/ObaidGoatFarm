import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/accounting/accounting_controller.dart';

class CreateAccountDialog extends ConsumerStatefulWidget {
  const CreateAccountDialog({super.key});

  @override
  ConsumerState<CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<CreateAccountDialog> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  String _type = 'ASSET';
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_codeController.text.trim().isEmpty || _nameController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(accountsControllerProvider.notifier)
          .create(code: _codeController.text.trim(), name: _nameController.text.trim(), type: _type);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (error) {
      final data = error.response?.data;
      setState(() {
        _isSubmitting = false;
        _errorMessage = data is Map && data['message'] is String ? data['message'] as String : 'Could not create the account.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
          ],
          TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'Code (e.g. 1050)')),
          const SizedBox(height: 12),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'ASSET', child: Text('Asset')),
              DropdownMenuItem(value: 'LIABILITY', child: Text('Liability')),
              DropdownMenuItem(value: 'EQUITY', child: Text('Equity')),
              DropdownMenuItem(value: 'INCOME', child: Text('Income')),
              DropdownMenuItem(value: 'EXPENSE', child: Text('Expense')),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}
