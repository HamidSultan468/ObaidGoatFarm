import 'package:flutter/material.dart';
import '../api/api_error.dart';

/// Shared scaffold for create/record dialogs: scrollable body, an error
/// line, a busy state on the submit button, and pop-on-success.
///
/// [validate] runs first and returns an error message to block submission
/// (no API call is made). [onSubmit] errors are shown via [apiErrorMessage].
class FormDialog extends StatefulWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.onSubmit,
    this.validate,
    this.submitLabel = 'Save',
    this.fallbackError = 'Could not save. Please try again.',
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function() onSubmit;
  final String? Function()? validate;
  final String submitLabel;
  final String fallbackError;

  @override
  State<FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    final validationError = widget.validate?.call();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = apiErrorMessage(error, widget.fallbackError);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
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
              for (final child in widget.children) ...[child, const SizedBox(height: 12)],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
