import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/farm/farm_format.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/whatsapp/whatsapp.dart';
import '../../../../core/widgets/form_dialog.dart';

/// WhatsApp: owners/admins connect the business number; members link their
/// own phone with a one-time code. Messages only ever create drafts.
class WhatsAppSection extends ConsumerStatefulWidget {
  const WhatsAppSection({super.key, required this.canManage});
  final bool canManage;

  @override
  ConsumerState<WhatsAppSection> createState() => _WhatsAppSectionState();
}

class _WhatsAppSectionState extends ConsumerState<WhatsAppSection> {
  final _phone = TextEditingController();
  LinkStart? _pending;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Something went wrong.'))));
    } finally {
      ref.invalidate(whatsAppConfigProvider);
      ref.invalidate(myWhatsAppLinkProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMessages() async {
    final messages = await ref.read(whatsAppRepositoryProvider).messages(requireWorkspaceIdFromWidget(ref));
    if (!mounted) return;
    final now = DateTime.now();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('WhatsApp message log'),
        content: SizedBox(
          width: 520,
          height: 420,
          child: messages.isEmpty
              ? const Center(child: Text('No messages yet.'))
              : ListView(
                  children: [
                    for (final m in messages)
                      ListTile(
                        dense: true,
                        leading: Icon(m.direction == 'INBOUND' ? Icons.call_received_rounded : Icons.call_made_rounded),
                        title: Text('${m.phoneE164} · ${humanizeEnum(m.status)} · ${timeAgo(m.createdAt, now)}'),
                        subtitle: Text([?m.body, if (m.error != null) 'Error: ${m.error}'].join('\n'), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(whatsAppConfigProvider);
    final myLink = ref.watch(myWhatsAppLinkProvider).value;
    final apiBase = ref.watch(apiClientProvider).raw.options.baseUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: config.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(apiErrorMessage(error, 'Could not load WhatsApp settings.')),
          data: (c) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('WhatsApp', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Send what happened from WhatsApp; it becomes a draft here that someone approves. Uses the official WhatsApp Business Cloud API.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (widget.canManage) ...[
                if (!c.configured)
                  const Text('Not connected yet.')
                else ...[
                  Text('Business number: ${c.displayPhone ?? c.phoneNumberId} · ${c.isEnabled ? 'on' : 'off'}'),
                  const SizedBox(height: 4),
                  _CopyRow(label: 'Webhook URL (public HTTPS address of this server)', value: '$apiBase${c.webhookPath}'),
                  _CopyRow(label: 'Verify token', value: c.verifyToken ?? ''),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => showDialog<bool>(context: context, builder: (_) => _ConnectDialog(existing: c)).then((_) => ref.invalidate(whatsAppConfigProvider)),
                      icon: const Icon(Icons.link_rounded),
                      label: Text(c.configured ? 'Update connection' : 'Connect WhatsApp Business'),
                    ),
                    if (c.configured) TextButton(onPressed: _busy ? null : _showMessages, child: const Text('Message log')),
                  ],
                ),
                const Divider(height: 24),
              ],
              Text('My phone', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              if (!c.configured)
                const Text('An owner or admin needs to connect WhatsApp first.')
              else if (myLink != null && myLink.verified)
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF22A559), size: 18),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Linked: ${myLink.phoneE164}')),
                    TextButton(onPressed: _busy ? null : () => _run(() => ref.read(whatsAppRepositoryProvider).unlink(requireWorkspaceIdFromWidget(ref))), child: const Text('Unlink')),
                  ],
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(width: 220, child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'My WhatsApp number', hintText: '0300 1234567', isDense: true))),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final start = await ref.read(whatsAppRepositoryProvider).startLink(requireWorkspaceIdFromWidget(ref), _phone.text.trim());
                              setState(() => _pending = start);
                            }),
                      child: const Text('Get link code'),
                    ),
                  ],
                ),
                if (_pending != null) ...[
                  const SizedBox(height: 8),
                  SelectableText('Code: ${_pending!.code}', style: Theme.of(context).textTheme.titleLarge),
                  Text(_pending!.instructions),
                  TextButton(onPressed: () => ref.invalidate(myWhatsAppLinkProvider), child: const Text('I sent it, check again')),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(label, style: Theme.of(context).textTheme.bodySmall), SelectableText(value)],
          ),
        ),
        IconButton(
          tooltip: 'Copy',
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: () => Clipboard.setData(ClipboardData(text: value)),
        ),
      ],
    );
  }
}

class _ConnectDialog extends ConsumerStatefulWidget {
  const _ConnectDialog({required this.existing});
  final WhatsAppConfigInfo existing;

  @override
  ConsumerState<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends ConsumerState<_ConnectDialog> {
  late final _phoneNumberId = TextEditingController(text: widget.existing.phoneNumberId ?? '');
  late final _display = TextEditingController(text: widget.existing.displayPhone ?? '');
  final _token = TextEditingController();
  final _secret = TextEditingController();
  late bool _enabled = widget.existing.configured ? widget.existing.isEnabled : true;

  @override
  void dispose() {
    for (final c in [_phoneNumberId, _display, _token, _secret]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'WhatsApp Business connection',
      fallbackError: 'Could not save the connection.',
      validate: () {
        if (!RegExp(r'^\d{5,30}$').hasMatch(_phoneNumberId.text.trim())) return 'Enter the numeric Phone number ID from Meta.';
        if (_token.text.trim().length < 20) return 'Paste the access token.';
        if (_secret.text.trim().length < 16) return 'Paste the app secret.';
        return null;
      },
      onSubmit: () => ref.read(whatsAppRepositoryProvider).saveConfig(requireWorkspaceIdFromWidget(ref), {
        'phoneNumberId': _phoneNumberId.text.trim(),
        if (_display.text.trim().isNotEmpty) 'displayPhone': _display.text.trim(),
        'accessToken': _token.text.trim(),
        'appSecret': _secret.text.trim(),
        'isEnabled': _enabled,
      }),
      children: [
        const Text('From Meta for Developers → your app → WhatsApp → API Setup. Token and secret are stored encrypted.'),
        TextField(controller: _phoneNumberId, decoration: const InputDecoration(labelText: 'Phone number ID')),
        TextField(controller: _display, decoration: const InputDecoration(labelText: 'Business phone (shown to members)')),
        TextField(controller: _token, obscureText: true, decoration: const InputDecoration(labelText: 'Permanent access token')),
        TextField(controller: _secret, obscureText: true, decoration: const InputDecoration(labelText: 'App secret')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enabled'), value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
      ],
    );
  }
}
