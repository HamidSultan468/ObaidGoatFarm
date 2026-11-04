import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/accounting/money_format.dart';
import '../../../../core/ai/ai.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/farm/farm_controller.dart';
import '../../../../core/farm/farm_format.dart';
import '../../../../core/farm/farm_repository.dart';
import '../../../../core/land/land.dart';
import '../../../../core/notifications/notifications.dart';
import '../../../../core/widgets/date_field.dart';

const _healthTypes = ['VACCINATION', 'DEWORMING', 'CHECKUP', 'ILLNESS', 'TREATMENT', 'MEDICATION', 'INJURY', 'OTHER'];

/// One draft with editable fields. Nothing is saved until "Approve & save";
/// the server validates the edited values again exactly like manual entry.
class DraftReviewCard extends ConsumerStatefulWidget {
  const DraftReviewCard({super.key, required this.draft});
  final RecordDraft draft;

  @override
  ConsumerState<DraftReviewCard> createState() => _DraftReviewCardState();
}

class _DraftReviewCardState extends ConsumerState<DraftReviewCard> {
  late final Map<String, dynamic> _p = Map.of(widget.draft.payload);
  late final _amount = TextEditingController(text: _p['amount'] as String? ?? '');
  late final _memo = TextEditingController(text: _p['memo'] as String? ?? '');
  late final _description = TextEditingController(text: _p['description'] as String? ?? '');
  late final _medication = TextEditingController(text: _p['medication'] as String? ?? '');
  late final _weight = TextEditingController(text: _p['weightKg'] as String? ?? '');
  bool _busy = false;
  String? _error;

  bool get _isMoney => widget.draft.kind == 'INCOME' || widget.draft.kind == 'EXPENSE';
  String get _cashKey => widget.draft.kind == 'INCOME' ? 'toAccountId' : 'fromAccountId';
  String get _categoryKey => widget.draft.kind == 'INCOME' ? 'incomeAccountId' : 'expenseAccountId';

  @override
  void dispose() {
    for (final c in [_amount, _memo, _description, _medication, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _collect() {
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final payload = Map<String, dynamic>.of(_p);
    if (_isMoney) {
      payload['amount'] = text(_amount);
      payload['memo'] = text(_memo);
    } else if (widget.draft.kind == 'ANIMAL_HEALTH') {
      payload['description'] = text(_description);
      payload['medication'] = text(_medication);
    } else {
      payload['weightKg'] = text(_weight);
    }
    payload.removeWhere((_, v) => v == null);
    return payload;
  }

  Future<void> _approve() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(aiRepositoryProvider).approve(requireWorkspaceIdFromWidget(ref), widget.draft.id, _collect());
      refreshDrafts(ref);
      refreshNotifications(ref);
      ref.invalidate(transactionsControllerProvider);
      invalidateFarm(ref, animalId: _p['animalId'] as String?);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved and saved.')));
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, 'Could not approve this draft.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref.read(aiRepositoryProvider).reject(requireWorkspaceIdFromWidget(ref), widget.draft.id);
      refreshDrafts(ref);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, 'Could not reject this draft.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dropdown(String label, String key, List<(String, String)> options, {bool optional = false}) {
    final value = options.any((o) => o.$1 == _p[key]) ? _p[key] as String : null;
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: optional ? '$label (optional)' : label, isDense: true),
      items: [
        if (optional || value == null) DropdownMenuItem<String?>(value: null, child: Text(optional ? 'None' : 'Choose…')),
        for (final (id, text) in options) DropdownMenuItem<String?>(value: id, child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: _busy ? null : (v) => setState(() => _p[key] = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final scheme = Theme.of(context).colorScheme;
    final accounts = ref.watch(accountsControllerProvider).value ?? const [];
    final animals = (ref.watch(allAnimalsProvider).value ?? const []).where((a) => a.isActive).toList();
    final parcels = ref.watch(allLandParcelsProvider).value ?? const [];
    final animalOptions = [for (final a in animals) (a.id, a.ref.label)];
    final pending = d.isPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Chip(label: Text(humanizeEnum(d.kind)), visualDensity: VisualDensity.compact),
                const SizedBox(width: 8),
                Text(
                  '${d.source == 'WHATSAPP' ? 'WhatsApp${d.sourcePhone != null ? ' ${d.sourcePhone}' : ''}' : (d.source == 'AI_RECEIPT' ? 'Receipt' : 'Typed')} · ${timeAgo(d.createdAt, DateTime.now())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (!pending) Chip(label: Text(humanizeEnum(d.status)), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 6),
            Text(d.summary, style: Theme.of(context).textTheme.titleSmall),
            if (d.rawInput != null) Text('“${d.rawInput}”', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            if (pending && d.warnings.isNotEmpty) ...[
              const SizedBox(height: 6),
              for (final w in d.warnings)
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(w, style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
            ],
            if (!pending) ...[
              const SizedBox(height: 6),
              if (_isMoney && d.payload['amount'] != null) Text('Amount ${formatMoney(d.payload['amount'] as String)}'),
              if (d.rejectReason != null) Text('Rejected: ${d.rejectReason}'),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_isMoney) ...[
                    SizedBox(width: 160, child: TextField(controller: _amount, enabled: !_busy, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', isDense: true))),
                    SizedBox(
                      width: 240,
                      child: _dropdown(d.kind == 'INCOME' ? 'Received into' : 'Paid from', _cashKey, [
                        for (final a in accounts.where((a) => a.kind == 'CASH' || a.kind == 'BANK')) (a.id, '${a.code} · ${a.name}'),
                      ]),
                    ),
                    SizedBox(
                      width: 240,
                      child: _dropdown('Category', _categoryKey, [
                        for (final a in accounts.where((a) => a.type == (d.kind == 'INCOME' ? 'INCOME' : 'EXPENSE'))) (a.id, '${a.code} · ${a.name}'),
                      ]),
                    ),
                    SizedBox(width: 240, child: _dropdown('Animal', 'animalId', animalOptions, optional: true)),
                    SizedBox(width: 240, child: _dropdown('Land', 'landParcelId', [for (final p in parcels) (p.id, p.name)], optional: true)),
                    SizedBox(width: 400, child: TextField(controller: _memo, enabled: !_busy, decoration: const InputDecoration(labelText: 'Memo', isDense: true))),
                  ],
                  if (d.kind == 'ANIMAL_HEALTH') ...[
                    SizedBox(width: 240, child: _dropdown('Animal', 'animalId', animalOptions)),
                    SizedBox(width: 200, child: _dropdown('Type', 'type', [for (final t in _healthTypes) (t, humanizeEnum(t))])),
                    SizedBox(
                      width: 200,
                      child: DateField(
                        label: 'Date',
                        value: _p['recordDate'] == null ? null : DateTime.parse(_p['recordDate'] as String),
                        onChanged: (v) => setState(() => _p['recordDate'] = apiDate(v)),
                      ),
                    ),
                    SizedBox(width: 400, child: TextField(controller: _description, enabled: !_busy, decoration: const InputDecoration(labelText: 'Description', isDense: true))),
                    SizedBox(width: 240, child: TextField(controller: _medication, enabled: !_busy, decoration: const InputDecoration(labelText: 'Medicine', isDense: true))),
                    SizedBox(
                      width: 200,
                      child: DateField(
                        label: 'Next due',
                        value: _p['nextDueDate'] == null ? null : DateTime.parse(_p['nextDueDate'] as String),
                        onChanged: (v) => setState(() => _p['nextDueDate'] = apiDate(v)),
                        onCleared: () => setState(() => _p.remove('nextDueDate')),
                      ),
                    ),
                  ],
                  if (d.kind == 'ANIMAL_WEIGHT') ...[
                    SizedBox(width: 240, child: _dropdown('Animal', 'animalId', animalOptions)),
                    SizedBox(width: 140, child: TextField(controller: _weight, enabled: !_busy, decoration: const InputDecoration(labelText: 'Weight (kg)', isDense: true))),
                    SizedBox(
                      width: 200,
                      child: DateField(
                        label: 'Date',
                        value: _p['recordDate'] == null ? null : DateTime.parse(_p['recordDate'] as String),
                        onChanged: (v) => setState(() => _p['recordDate'] = apiDate(v)),
                      ),
                    ),
                  ],
                ],
              ),
              if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: scheme.error))],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(onPressed: _busy ? null : _approve, icon: const Icon(Icons.check_rounded), label: const Text('Approve & save')),
                  OutlinedButton(onPressed: _busy ? null : _reject, child: const Text('Reject')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
