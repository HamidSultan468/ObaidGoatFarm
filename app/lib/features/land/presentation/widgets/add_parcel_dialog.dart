import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/farm/farm_repository.dart';
import '../../../../core/land/land.dart';
import '../../../../core/widgets/date_field.dart';
import '../../../../core/widgets/form_dialog.dart';
import '../../../goat_farm/presentation/widgets/animal_dialogs.dart' show enumDropdown;

final _areaPattern = RegExp(r'^\d{1,12}(\.\d{1,4})?$');

class AddParcelDialog extends ConsumerStatefulWidget {
  const AddParcelDialog({super.key});

  @override
  ConsumerState<AddParcelDialog> createState() => _AddParcelDialogState();
}

class _AddParcelDialogState extends ConsumerState<AddParcelDialog> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _survey = TextEditingController();
  final _owner = TextEditingController();
  final _area = TextEditingController();
  final _use = TextEditingController();
  final _leaseTerms = TextEditingController();
  final _notes = TextEditingController();
  String _unit = 'KANAL';
  String _tenure = 'OWNED';
  String? _contactId;
  DateTime? _acquired;
  DateTime? _leaseStart;
  DateTime? _leaseEnd;

  @override
  void dispose() {
    for (final c in [_name, _location, _survey, _owner, _area, _use, _leaseTerms, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Enter a name for this land.';
    final area = _area.text.trim();
    if (!_areaPattern.hasMatch(area) || RegExp(r'^0+(\.0+)?$').hasMatch(area)) return 'Enter the area, e.g. 12 or 2.5';
    if (_leaseStart != null && _leaseEnd != null && _leaseEnd!.isBefore(_leaseStart!)) return 'Lease end cannot be before lease start.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsControllerProvider).value ?? const [];
    final leased = _tenure != 'OWNED';
    return FormDialog(
      title: 'Add land',
      submitLabel: 'Add',
      fallbackError: 'Could not add the land record.',
      validate: _validate,
      onSubmit: () async {
        await ref.read(landRepositoryProvider).create(requireWorkspaceIdFromWidget(ref), {
          'name': _name.text.trim(),
          'areaValue': _area.text.trim(),
          'areaUnit': _unit,
          'tenure': _tenure,
          'location': ?_optional(_location),
          'surveyNumber': ?_optional(_survey),
          'ownerName': ?_optional(_owner),
          'landUse': ?_optional(_use),
          'notes': ?_optional(_notes),
          if (_acquired != null) 'acquisitionDate': apiDate(_acquired!),
          if (leased) ...{
            'counterpartyContactId': ?_contactId,
            if (_leaseStart != null) 'leaseStartDate': apiDate(_leaseStart!),
            if (_leaseEnd != null) 'leaseEndDate': apiDate(_leaseEnd!),
            'leaseTerms': ?_optional(_leaseTerms),
          },
        });
        invalidateLand(ref);
      },
      children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name *  (e.g. North field)')),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _area,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Area *'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: enumDropdown(label: 'Unit', value: _unit, values: areaUnits, onChanged: (v) => setState(() => _unit = v))),
          ],
        ),
        Text('1 kanal = 20 marla · 1 acre = 8 kanal · 1 marla = 272.25 sq ft', style: Theme.of(context).textTheme.bodySmall),
        TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location (village / tehsil / district)')),
        TextField(controller: _survey, decoration: const InputDecoration(labelText: 'Khasra / survey number')),
        enumDropdown(
          label: 'Tenure',
          value: _tenure,
          values: const ['OWNED', 'LEASED_IN', 'LEASED_OUT', 'RENTED_OUT'],
          onChanged: (v) => setState(() => _tenure = v),
        ),
        TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner name (as on record)')),
        TextField(controller: _use, decoration: const InputDecoration(labelText: 'Land use (e.g. wheat, fodder, orchard)')),
        DateField(
          label: 'Acquisition date',
          value: _acquired,
          lastDate: DateTime.now(),
          onChanged: (d) => setState(() => _acquired = d),
          onCleared: () => setState(() => _acquired = null),
        ),
        if (leased) ...[
          DropdownButtonFormField<String?>(
            initialValue: _contactId,
            isExpanded: true,
            decoration: InputDecoration(labelText: _tenure == 'LEASED_IN' ? 'Landlord (contact)' : 'Tenant (contact)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              for (final c in contacts) DropdownMenuItem<String?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _contactId = v),
          ),
          DateField(label: 'Lease start', value: _leaseStart, onChanged: (d) => setState(() => _leaseStart = d), onCleared: () => setState(() => _leaseStart = null)),
          DateField(label: 'Lease end', value: _leaseEnd, onChanged: (d) => setState(() => _leaseEnd = d), onCleared: () => setState(() => _leaseEnd = null)),
          TextField(controller: _leaseTerms, maxLines: 2, decoration: const InputDecoration(labelText: 'Lease terms (rent, payment schedule)')),
        ],
        TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
      ],
    );
  }
}
