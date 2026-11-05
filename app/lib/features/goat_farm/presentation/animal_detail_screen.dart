import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accounting/accounting_controller.dart';
import '../../../core/accounting/money_format.dart';
import '../../../core/api/api_error.dart';
import '../../../core/farm/farm_controller.dart';
import '../../../core/farm/farm_format.dart';
import '../../../core/farm/farm_models.dart';
import '../../documents/presentation/widgets/attachments_card.dart';
import 'widgets/animal_dialogs.dart';
import 'widgets/animal_photo_avatar.dart';
import 'widgets/breeding_dialogs.dart';

class AnimalDetailScreen extends ConsumerWidget {
  const AnimalDetailScreen({super.key, required this.animalId});
  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalAsync = ref.watch(animalDetailProvider(animalId));
    return animalAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiErrorMessage(error, 'Could not load this animal.')),
            TextButton(onPressed: () => context.go('/goat-farm'), child: const Text('Back to herd')),
          ],
        ),
      ),
      data: (animal) => _AnimalDetail(animal: animal),
    );
  }
}

class _AnimalDetail extends ConsumerWidget {
  const _AnimalDetail({required this.animal});
  final Animal animal;

  Future<void> _setHealth(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref
          .read(farmRepositoryProvider)
          .updateAnimal(requireWorkspaceIdFromWidget(ref), animal.id, {'healthStatus': status}, ifMatch: animal.updatedAt);
      invalidateFarm(ref, animalId: animal.id);
    } on DioException catch (error) {
      if (!context.mounted) return;
      // 412: someone else changed this animal since this screen was opened.
      // Refresh instead of silently overwriting their change, then let the
      // user re-apply their change against the current data.
      invalidateFarm(ref, animalId: animal.id);
      final message = error.response?.statusCode == 412
          ? 'Someone else updated this animal just now. Reloaded the latest — please try again.'
          : apiErrorMessage(error, 'Could not update health status.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not update health status.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            IconButton(tooltip: 'Back to herd', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/goat-farm')),
            const SizedBox(width: 8),
            AnimalPhotoAvatar(animal: animal, radius: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(animal.ref.label, style: Theme.of(context).textTheme.headlineSmall, overflow: TextOverflow.ellipsis)),
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => showDialog<bool>(context: context, builder: (_) => EditAnimalDialog(animal: animal)),
            ),
            if (animal.isActive)
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (action) => switch (action) {
                  'MATING' => showDialog<bool>(context: context, builder: (_) => CreateBreedingDialog(initialDamId: animal.id)),
                  'EXIT' => showDialog<bool>(context: context, builder: (_) => RecordExitDialog(animal: animal)),
                  _ => null,
                },
                itemBuilder: (_) => [
                  if (animal.sex == 'FEMALE') const PopupMenuItem(value: 'MATING', child: Text('Record mating')),
                  const PopupMenuItem(value: 'EXIT', child: Text('Mark sold / deceased')),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(humanizeEnum(animal.status))),
            Chip(label: Text(humanizeEnum(animal.sex))),
            if (animal.isActive)
              PopupMenuButton<String>(
                tooltip: 'Change health status',
                onSelected: (status) => _setHealth(context, ref, status),
                itemBuilder: (_) => [
                  for (final s in const ['HEALTHY', 'SICK', 'UNDER_TREATMENT', 'QUARANTINED'])
                    PopupMenuItem(value: s, child: Text(humanizeEnum(s))),
                ],
                child: Chip(avatar: const Icon(Icons.edit_rounded, size: 16), label: Text(humanizeEnum(animal.healthStatus))),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final left = [_ProfileCard(animal: animal, now: now), _FinanceCard(animalId: animal.id)];
            final right = [
              _WeightCard(animal: animal),
              _HealthCard(animal: animal, now: now),
              AttachmentsCard(module: 'ANIMAL', recordId: animal.id),
            ];
            if (!wide) return Column(children: [...left, ...right]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: left)),
                const SizedBox(width: 16),
                Expanded(child: Column(children: right)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)), ?action]),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.animal, required this.now});
  final Animal animal;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final age = ageLabel(animal.dateOfBirth, now);
    return _Section(
      title: 'Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field('Tag number', animal.tagNumber),
          _Field('Species / breed', [humanizeEnum(animal.species), ?animal.breed].join(' · ')),
          if (animal.dateOfBirth != null) _Field('Born', '${formatDate(animal.dateOfBirth!)}${age != null ? ' ($age)' : ''}'),
          _Field('Acquired', [humanizeEnum(animal.acquisition), if (animal.acquisitionDate != null) formatDate(animal.acquisitionDate!)].join(' · ')),
          if (animal.color != null) _Field('Color', animal.color!),
          if (animal.ownership != null) _Field('Owner', animal.ownership!),
          _ParentField('Sire', animal.sire),
          _ParentField('Dam', animal.dam),
          if (animal.dietaryRestrictions != null) _Field('Diet', animal.dietaryRestrictions!),
          if (animal.notes != null) _Field('Notes', animal.notes!),
          if (!animal.isActive)
            _Field('Exit', [formatDate(animal.exitDate!), ?animal.exitReason].join(' · ')),
          if (animal.offspring.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Offspring (${animal.offspring.length})', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final kid in animal.offspring)
                  ActionChip(label: Text(kid.label), onPressed: () => context.go('/goat-farm/animals/${kid.id}')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ParentField extends StatelessWidget {
  const _ParentField(this.label, this.parent);
  final String label;
  final AnimalRef? parent;

  @override
  Widget build(BuildContext context) {
    if (parent == null) return _Field(label, 'Unknown');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          InkWell(
            onTap: () => context.go('/goat-farm/animals/${parent!.id}'),
            child: Text(parent!.label, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}

class _FinanceCard extends ConsumerWidget {
  const _FinanceCard({required this.animalId});
  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(animalLedgerProvider(animalId));
    return _Section(
      title: 'Finances',
      child: ledger.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text(apiErrorMessage(error, 'Could not load finances.')),
        data: (p) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Field('Income', formatMoney(p.income)),
            _Field('Expenses', formatMoney(p.expense)),
            _Field('Net', formatMoney(p.net)),
            const SizedBox(height: 4),
            Text(
              'From income and expenses tagged with this animal in Bank & Accounts.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightCard extends ConsumerWidget {
  const _WeightCard({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weights = ref.watch(weightsProvider(animal.id));
    return _Section(
      title: 'Weight',
      action: animal.isActive
          ? TextButton.icon(
              onPressed: () => showDialog<bool>(context: context, builder: (_) => AddWeightDialog(animalId: animal.id)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record'),
            )
          : null,
      child: weights.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text(apiErrorMessage(error, 'Could not load weights.')),
        data: (records) {
          if (records.isEmpty) return const Text('No weights recorded.');
          return Column(
            children: [
              for (final record in records.reversed)
                _Field(formatDate(record.recordDate), '${trimDecimal(record.weightKg)} kg'),
            ],
          );
        },
      ),
    );
  }
}

class _HealthCard extends ConsumerWidget {
  const _HealthCard({required this.animal, required this.now});
  final Animal animal;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(healthRecordsProvider(animal.id));
    return _Section(
      title: 'Health & vet records',
      action: animal.isActive
          ? TextButton.icon(
              onPressed: () => showDialog<bool>(context: context, builder: (_) => AddHealthRecordDialog(animalId: animal.id)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : null,
      child: records.when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Text(apiErrorMessage(error, 'Could not load health records.')),
        data: (list) {
          if (list.isEmpty) return const Text('No health records yet.');
          return Column(
            children: [
              for (final r in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.medical_services_outlined),
                  title: Text('${humanizeEnum(r.type)} · ${formatDate(r.recordDate)}'),
                  subtitle: Text([
                    r.description,
                    if (r.medication != null) '${r.medication}${r.dosage != null ? ' (${r.dosage})' : ''}',
                    if (r.veterinarian != null) 'Vet: ${r.veterinarian}',
                    if (r.nextDueDate != null) 'Next due ${formatDate(r.nextDueDate!)} (${dueLabel(r.nextDueDate!, now)})',
                  ].join('\n')),
                ),
            ],
          );
        },
      ),
    );
  }
}
