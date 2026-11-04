import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/farm/farm_controller.dart';
import '../../../../core/farm/farm_format.dart';
import '../../../../core/farm/farm_models.dart';
import '../../../../core/farm/farm_repository.dart';
import '../../../../core/widgets/date_field.dart';
import '../../../../core/widgets/form_dialog.dart';
import 'animal_dialogs.dart';

final _tagPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/.]{0,39}$');

class CreateBreedingDialog extends ConsumerStatefulWidget {
  const CreateBreedingDialog({super.key, this.initialDamId});
  final String? initialDamId;

  @override
  ConsumerState<CreateBreedingDialog> createState() => _CreateBreedingDialogState();
}

class _CreateBreedingDialogState extends ConsumerState<CreateBreedingDialog> {
  final _externalSire = TextEditingController();
  final _notes = TextEditingController();
  late String? _damId = widget.initialDamId;
  String? _sireId;
  String _method = 'NATURAL';
  DateTime _matingDate = DateTime.now().toUtc();

  @override
  void dispose() {
    _externalSire.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animals = (ref.watch(allAnimalsProvider).value ?? const <Animal>[]).where((a) => a.isActive).toList();
    return FormDialog(
      title: 'Record mating',
      fallbackError: 'Could not save the mating record.',
      validate: () {
        if (_damId == null) return 'Choose the doe (dam).';
        if (_sireId != null && _externalSire.text.trim().isNotEmpty) return 'Choose a buck from the farm or type an outside sire, not both.';
        return null;
      },
      onSubmit: () async {
        final external = _externalSire.text.trim();
        final notes = _notes.text.trim();
        await ref.read(farmRepositoryProvider).createBreeding(requireWorkspaceIdFromWidget(ref), {
          'damId': _damId,
          'sireId': ?_sireId,
          if (external.isNotEmpty) 'externalSire': external,
          'method': _method,
          'matingDate': apiDate(_matingDate),
          if (notes.isNotEmpty) 'notes': notes,
        });
        invalidateFarm(ref, animalId: _damId);
      },
      children: [
        animalPicker(
          label: 'Doe (dam) *',
          value: _damId,
          animals: animals.where((a) => a.sex == 'FEMALE').toList(),
          onChanged: (v) => setState(() => _damId = v),
        ),
        animalPicker(
          label: 'Buck (sire) from this farm',
          value: _sireId,
          animals: animals.where((a) => a.sex == 'MALE').toList(),
          onChanged: (v) => setState(() => _sireId = v),
        ),
        TextField(controller: _externalSire, decoration: const InputDecoration(labelText: '…or outside sire / AI straw')),
        enumDropdown(
          label: 'Method',
          value: _method,
          values: const ['NATURAL', 'ARTIFICIAL_INSEMINATION'],
          onChanged: (v) => setState(() => _method = v),
        ),
        DateField(label: 'Mating date', value: _matingDate, lastDate: DateTime.now(), onChanged: (d) => setState(() => _matingDate = d)),
        Text(
          'Expected kidding: ${formatDate(_matingDate.add(const Duration(days: 150)))} (150 days)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
      ],
    );
  }
}

class _KidRow {
  final tag = TextEditingController();
  final name = TextEditingController();
  String sex = 'FEMALE';

  void dispose() {
    tag.dispose();
    name.dispose();
  }
}

class RecordKiddingDialog extends ConsumerStatefulWidget {
  const RecordKiddingDialog({super.key, required this.record});
  final BreedingRecord record;

  @override
  ConsumerState<RecordKiddingDialog> createState() => _RecordKiddingDialogState();
}

class _RecordKiddingDialogState extends ConsumerState<RecordKiddingDialog> {
  final _complications = TextEditingController();
  final List<_KidRow> _kids = [_KidRow()];
  late int _kidsBorn = 1;
  DateTime _date = DateTime.now().toUtc();

  @override
  void dispose() {
    _complications.dispose();
    for (final kid in _kids) {
      kid.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_kids.length > _kidsBorn) return 'More live kids listed than born.';
    final tags = <String>{};
    for (final kid in _kids) {
      final tag = kid.tag.text.trim();
      if (!_tagPattern.hasMatch(tag)) return 'Give every kid a tag number.';
      if (!tags.add(tag)) return 'Kid tag numbers must be different.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Record kidding · ${widget.record.dam.label}',
      fallbackError: 'Could not record the kidding.',
      validate: _validate,
      onSubmit: () async {
        await ref.read(farmRepositoryProvider).recordKidding(
          requireWorkspaceIdFromWidget(ref),
          widget.record.id,
          kiddingDate: _date,
          kidsBorn: _kidsBorn,
          kids: [
            for (final kid in _kids)
              NewKid(tagNumber: kid.tag.text.trim(), sex: kid.sex, name: kid.name.text.trim().isEmpty ? null : kid.name.text.trim()),
          ],
          complications: _complications.text.trim(),
        );
        invalidateFarm(ref, animalId: widget.record.dam.id);
      },
      children: [
        DateField(label: 'Kidding date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d)),
        DropdownButtonFormField<int>(
          initialValue: _kidsBorn,
          decoration: const InputDecoration(labelText: 'Total kids born (incl. stillborn)'),
          items: [for (var i = 0; i <= 6; i++) DropdownMenuItem(value: i, child: Text('$i'))],
          onChanged: (v) => setState(() => _kidsBorn = v ?? _kidsBorn),
        ),
        Text('Live kids to register', style: Theme.of(context).textTheme.titleSmall),
        for (final (index, kid) in _kids.indexed)
          Row(
            key: ObjectKey(kid),
            children: [
              Expanded(flex: 3, child: TextField(controller: kid.tag, decoration: InputDecoration(labelText: 'Kid ${index + 1} tag *'))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: kid.sex,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  ],
                  onChanged: (v) => setState(() => kid.sex = v ?? kid.sex),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: () {
                  final removed = _kids[index];
                  setState(() => _kids.removeAt(index));
                  // Dispose after this frame: the removed TextFields still hold the controllers until rebuilt.
                  WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
                },
              ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _kids.length >= 6 ? null : () => setState(() => _kids.add(_KidRow())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add kid'),
          ),
        ),
        TextField(controller: _complications, decoration: const InputDecoration(labelText: 'Complications (optional)')),
      ],
    );
  }
}
