import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/farm/farm_controller.dart';
import '../../../../core/farm/farm_format.dart';
import '../../../../core/farm/farm_models.dart';
import '../../../../core/farm/farm_repository.dart';
import '../../../../core/offline/outbox_controller.dart';
import '../../../../core/offline/outbox_models.dart';
import '../../../../core/widgets/date_field.dart';
import '../../../../core/widgets/form_dialog.dart';

final _tagPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-/.]{0,39}$');
final _weightPattern = RegExp(r'^\d{1,4}(\.\d{1,3})?$');

String? _optional(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}

/// Dropdown of animals filtered by sex, with a "None" entry.
Widget animalPicker({
  required String label,
  required String? value,
  required List<Animal> animals,
  required ValueChanged<String?> onChanged,
}) {
  return DropdownButtonFormField<String?>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem<String?>(value: null, child: Text('None')),
      for (final animal in animals)
        DropdownMenuItem<String?>(value: animal.id, child: Text(animal.ref.label, overflow: TextOverflow.ellipsis)),
    ],
    onChanged: onChanged,
  );
}

Widget enumDropdown({
  required String label,
  required String value,
  required List<String> values,
  required ValueChanged<String> onChanged,
}) {
  return DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [for (final v in values) DropdownMenuItem(value: v, child: Text(humanizeEnum(v)))],
    onChanged: (v) => onChanged(v ?? value),
  );
}

class AddAnimalDialog extends ConsumerStatefulWidget {
  const AddAnimalDialog({super.key});

  @override
  ConsumerState<AddAnimalDialog> createState() => _AddAnimalDialogState();
}

class _AddAnimalDialogState extends ConsumerState<AddAnimalDialog> {
  final _tag = TextEditingController();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _color = TextEditingController();
  final _ownership = TextEditingController();
  final _diet = TextEditingController();
  final _notes = TextEditingController();
  String _sex = 'FEMALE';
  String _acquisition = 'PURCHASED';
  DateTime? _dateOfBirth;
  DateTime? _acquisitionDate;
  String? _sireId;
  String? _damId;

  @override
  void dispose() {
    for (final c in [_tag, _name, _breed, _color, _ownership, _diet, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animals = ref.watch(allAnimalsProvider).value ?? const <Animal>[];
    return FormDialog(
      title: 'Add animal',
      submitLabel: 'Add',
      fallbackError: 'Could not add the animal.',
      validate: () => _tagPattern.hasMatch(_tag.text.trim()) ? null : 'Enter a tag number (letters, digits, - / .).',
      onSubmit: () async {
        await ref.read(farmRepositoryProvider).createAnimal(requireWorkspaceIdFromWidget(ref), {
          'tagNumber': _tag.text.trim(),
          'sex': _sex,
          'acquisition': _acquisition,
          'name': ?_optional(_name),
          'breed': ?_optional(_breed),
          'color': ?_optional(_color),
          'ownership': ?_optional(_ownership),
          'dietaryRestrictions': ?_optional(_diet),
          'notes': ?_optional(_notes),
          if (_dateOfBirth != null) 'dateOfBirth': apiDate(_dateOfBirth!),
          if (_acquisitionDate != null) 'acquisitionDate': apiDate(_acquisitionDate!),
          'sireId': ?_sireId,
          'damId': ?_damId,
        });
        invalidateFarm(ref);
      },
      children: [
        TextField(controller: _tag, decoration: const InputDecoration(labelText: 'Tag number *')),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        enumDropdown(label: 'Sex *', value: _sex, values: const ['FEMALE', 'MALE'], onChanged: (v) => setState(() => _sex = v)),
        TextField(controller: _breed, decoration: const InputDecoration(labelText: 'Breed (e.g. Beetal, Teddy)')),
        DateField(
          label: 'Date of birth',
          value: _dateOfBirth,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _dateOfBirth = d),
          onCleared: () => setState(() => _dateOfBirth = null),
        ),
        enumDropdown(
          label: 'Acquired by',
          value: _acquisition,
          values: const ['PURCHASED', 'BORN_ON_FARM', 'GIFTED', 'OTHER'],
          onChanged: (v) => setState(() => _acquisition = v),
        ),
        DateField(
          label: 'Acquisition date',
          value: _acquisitionDate,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _acquisitionDate = d),
          onCleared: () => setState(() => _acquisitionDate = null),
        ),
        animalPicker(
          label: 'Sire (father)',
          value: _sireId,
          animals: animals.where((a) => a.sex == 'MALE').toList(),
          onChanged: (v) => setState(() => _sireId = v),
        ),
        animalPicker(
          label: 'Dam (mother)',
          value: _damId,
          animals: animals.where((a) => a.sex == 'FEMALE').toList(),
          onChanged: (v) => setState(() => _damId = v),
        ),
        TextField(controller: _color, decoration: const InputDecoration(labelText: 'Color / markings')),
        TextField(controller: _ownership, decoration: const InputDecoration(labelText: 'Owner (if held for someone else)')),
        TextField(controller: _diet, decoration: const InputDecoration(labelText: 'Dietary restrictions')),
        TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
      ],
    );
  }
}

class AddHealthRecordDialog extends ConsumerStatefulWidget {
  const AddHealthRecordDialog({super.key, required this.animalId});
  final String animalId;

  @override
  ConsumerState<AddHealthRecordDialog> createState() => _AddHealthRecordDialogState();
}

class _AddHealthRecordDialogState extends ConsumerState<AddHealthRecordDialog> {
  final _description = TextEditingController();
  final _medication = TextEditingController();
  final _dosage = TextEditingController();
  final _vet = TextEditingController();
  String _type = 'VACCINATION';
  DateTime _recordDate = DateTime.now().toUtc();
  DateTime? _nextDue;

  @override
  void dispose() {
    for (final c in [_description, _medication, _dosage, _vet]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Add health record',
      fallbackError: 'Could not save the health record.',
      validate: () {
        if (_description.text.trim().isEmpty) return 'Enter a description.';
        if (_nextDue != null && daysUntil(_nextDue!, _recordDate) < 0) return 'Next due date cannot be before the record date.';
        return null;
      },
      onSubmit: () async {
        final messenger = ScaffoldMessenger.of(context);
        final result = await ref
            .read(outboxControllerProvider.notifier)
            .submit(
              workspaceId: requireWorkspaceIdFromWidget(ref),
              kind: OutboxKind.animalHealth,
              summary: 'Health record: ${humanizeEnum(_type)}',
              animalId: widget.animalId,
              payload: {
                'type': _type,
                'recordDate': apiDate(_recordDate),
                'description': _description.text.trim(),
                'medication': ?_optional(_medication),
                'dosage': ?_optional(_dosage),
                'veterinarian': ?_optional(_vet),
                if (_nextDue != null) 'nextDueDate': apiDate(_nextDue!),
              },
            );
        switch (result) {
          case OutboxSubmitSynced():
            invalidateFarm(ref, animalId: widget.animalId);
          case OutboxSubmitQueued():
            messenger.showSnackBar(
              const SnackBar(content: Text('No connection — saved and will post automatically once you\'re back online.')),
            );
          case OutboxSubmitRejected(:final message):
            throw AppMessageException(message);
        }
      },
      children: [
        enumDropdown(
          label: 'Type',
          value: _type,
          values: const ['VACCINATION', 'DEWORMING', 'CHECKUP', 'ILLNESS', 'TREATMENT', 'MEDICATION', 'INJURY', 'OTHER'],
          onChanged: (v) => setState(() => _type = v),
        ),
        DateField(label: 'Date', value: _recordDate, lastDate: DateTime.now(), onChanged: (d) => setState(() => _recordDate = d)),
        TextField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Description *')),
        TextField(controller: _medication, decoration: const InputDecoration(labelText: 'Medicine / vaccine')),
        TextField(controller: _dosage, decoration: const InputDecoration(labelText: 'Dosage')),
        TextField(controller: _vet, decoration: const InputDecoration(labelText: 'Veterinarian')),
        DateField(
          label: 'Next due (follow-up / booster)',
          value: _nextDue,
          onChanged: (d) => setState(() => _nextDue = d),
          onCleared: () => setState(() => _nextDue = null),
        ),
      ],
    );
  }
}

class AddWeightDialog extends ConsumerStatefulWidget {
  const AddWeightDialog({super.key, required this.animalId});
  final String animalId;

  @override
  ConsumerState<AddWeightDialog> createState() => _AddWeightDialogState();
}

class _AddWeightDialogState extends ConsumerState<AddWeightDialog> {
  final _weight = TextEditingController();
  DateTime _date = DateTime.now().toUtc();

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Record weight',
      fallbackError: 'Could not save the weight.',
      validate: () {
        final text = _weight.text.trim();
        if (!_weightPattern.hasMatch(text) || RegExp(r'^0+(\.0+)?$').hasMatch(text)) {
          return 'Enter a weight in kg, e.g. 32.5';
        }
        return null;
      },
      onSubmit: () async {
        final messenger = ScaffoldMessenger.of(context);
        final result = await ref
            .read(outboxControllerProvider.notifier)
            .submit(
              workspaceId: requireWorkspaceIdFromWidget(ref),
              kind: OutboxKind.animalWeight,
              summary: 'Weight: ${_weight.text.trim()} kg',
              animalId: widget.animalId,
              payload: {'recordDate': apiDate(_date), 'weightKg': _weight.text.trim()},
            );
        switch (result) {
          case OutboxSubmitSynced():
            invalidateFarm(ref, animalId: widget.animalId);
          case OutboxSubmitQueued():
            messenger.showSnackBar(
              const SnackBar(content: Text('No connection — saved and will post automatically once you\'re back online.')),
            );
          case OutboxSubmitRejected(:final message):
            throw AppMessageException(message);
        }
      },
      children: [
        DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d)),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight (kg) *', suffixText: 'kg'),
        ),
      ],
    );
  }
}

class RecordExitDialog extends ConsumerStatefulWidget {
  const RecordExitDialog({super.key, required this.animal});
  final Animal animal;

  @override
  ConsumerState<RecordExitDialog> createState() => _RecordExitDialogState();
}

class _RecordExitDialogState extends ConsumerState<RecordExitDialog> {
  final _reason = TextEditingController();
  String _status = 'SOLD';
  DateTime _date = DateTime.now().toUtc();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormDialog(
      title: 'Mark ${widget.animal.tagNumber} as sold or deceased',
      submitLabel: 'Confirm',
      fallbackError: 'Could not update the animal.',
      onSubmit: () async {
        await ref.read(farmRepositoryProvider).recordExit(
          requireWorkspaceIdFromWidget(ref),
          widget.animal.id,
          status: _status,
          exitDate: _date,
          reason: _reason.text.trim(),
        );
        invalidateFarm(ref, animalId: widget.animal.id);
      },
      children: [
        const Text('This cannot be undone. The animal\'s full history is kept. Record the sale money separately as income.'),
        enumDropdown(label: 'Status', value: _status, values: const ['SOLD', 'DECEASED'], onChanged: (v) => setState(() => _status = v)),
        DateField(label: 'Date', value: _date, lastDate: DateTime.now(), onChanged: (d) => setState(() => _date = d)),
        TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason / buyer (optional)')),
      ],
    );
  }
}
