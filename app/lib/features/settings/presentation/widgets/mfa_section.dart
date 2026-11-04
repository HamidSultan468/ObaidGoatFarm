import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_models.dart';
import '../../../../core/auth/mfa_controller.dart';
import '../../../../core/l10n/generated/app_localizations.dart';

class MfaSection extends ConsumerWidget {
  const MfaSection({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupState = ref.watch(mfaSetupControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)!.settingsSecuritySection, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (setupState is MfaSetupInProgress)
              _SetupInProgress(setupState: setupState)
            else
              _SetupIdle(enabled: profile.mfaEnabled),
          ],
        ),
      ),
    );
  }
}

class _SetupIdle extends ConsumerWidget {
  const _SetupIdle({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Icon(
          enabled ? Icons.check_circle_rounded : Icons.cancel_outlined,
          color: enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(enabled ? 'Enabled' : 'Not enabled on your account')),
        if (enabled)
          OutlinedButton(
            onPressed: () => _showDisableDialog(context, ref),
            child: Text(AppLocalizations.of(context)!.disable),
          )
        else
          FilledButton(
            onPressed: () => ref.read(mfaSetupControllerProvider.notifier).start(),
            child: Text(AppLocalizations.of(context)!.enable),
          ),
      ],
    );
  }

  Future<void> _showDisableDialog(BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Disable MFA'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your current 6-digit code to confirm.'),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(counterText: '', errorText: errorMessage),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await ref.read(authRepositoryProvider).disableMfa(codeController.text.trim());
                  await ref.read(authControllerProvider.notifier).refreshProfile();
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                } on DioException catch (error) {
                  final data = error.response?.data;
                  setState(() {
                    errorMessage = data is Map && data['message'] is String ? data['message'] as String : 'Invalid code';
                  });
                }
              },
              child: const Text('Disable'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupInProgress extends ConsumerStatefulWidget {
  const _SetupInProgress({required this.setupState});
  final MfaSetupInProgress setupState;

  @override
  ConsumerState<_SetupInProgress> createState() => _SetupInProgressState();
}

class _SetupInProgressState extends ConsumerState<_SetupInProgress> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Scan this with your authenticator app (Google Authenticator, Authy, etc.), or enter the key manually.'),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: QrImageView(data: widget.setupState.setup.otpauthUrl, size: 180),
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          widget.setupState.setup.secret,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2),
        ),
        const SizedBox(height: 16),
        if (widget.setupState.errorMessage != null) ...[
          Text(widget.setupState.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(counterText: '', labelText: 'Enter the 6-digit code to confirm'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref.read(mfaSetupControllerProvider.notifier).cancel(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: widget.setupState.isSubmitting
                    ? null
                    : () => ref.read(mfaSetupControllerProvider.notifier).confirm(_codeController.text.trim()),
                child: widget.setupState.isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
