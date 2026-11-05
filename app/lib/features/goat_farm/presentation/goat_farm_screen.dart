import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_error.dart';
import '../../../core/accounting/accounting_controller.dart';
import '../../../core/farm/farm_controller.dart';
import '../../../core/farm/farm_format.dart';
import '../../../core/farm/farm_models.dart';
import 'widgets/animal_dialogs.dart';
import 'widgets/animal_photo_avatar.dart';
import 'widgets/breeding_dialogs.dart';

class GoatFarmScreen extends ConsumerWidget {
  const GoatFarmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text('Goat Farm', style: Theme.of(context).textTheme.headlineSmall),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog<bool>(context: context, builder: (_) => const CreateBreedingDialog()),
                      icon: const Icon(Icons.favorite_border_rounded),
                      label: const Text('Record mating'),
                    ),
                    FilledButton.icon(
                      onPressed: () => showDialog<bool>(context: context, builder: (_) => const AddAnimalDialog()),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add animal'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _OverviewStrip(),
            const SizedBox(height: 8),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [Tab(text: 'Herd'), Tab(text: 'Breeding'), Tab(text: 'Schedule')],
            ),
            const Expanded(child: TabBarView(children: [_HerdTab(), _BreedingTab(), _ScheduleTab()])),
          ],
        ),
      ),
    );
  }
}

class _OverviewStrip extends ConsumerWidget {
  const _OverviewStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(farmOverviewProvider);
    return overview.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text(apiErrorMessage(error, 'Could not load the farm overview.')),
      data: (o) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Stat(label: 'Active animals', value: '${o.activeAnimals}', detail: '${o.females} F · ${o.males} M', icon: Icons.pets_rounded),
          _Stat(label: 'Need attention', value: '${o.needsAttention}', detail: '${o.healthy} healthy', icon: Icons.healing_rounded, alert: o.needsAttention > 0),
          _Stat(label: 'Pregnant', value: '${o.pregnant}', detail: '${o.upcomingKiddings.length} due in 30 days', icon: Icons.child_friendly_rounded),
          _Stat(
            label: 'Health tasks',
            value: '${o.dueHealth.length}',
            detail: '${o.dueHealth.where((d) => d.overdue).length} overdue',
            icon: Icons.vaccines_rounded,
            alert: o.dueHealth.any((d) => d.overdue),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.detail, required this.icon, this.alert = false});

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 180,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: alert ? scheme.error : scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                    Text(detail, style: Theme.of(context).textTheme.labelSmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HerdTab extends ConsumerStatefulWidget {
  const _HerdTab();

  @override
  ConsumerState<_HerdTab> createState() => _HerdTabState();
}

class _HerdTabState extends ConsumerState<_HerdTab> {
  late final _search = TextEditingController(text: ref.read(herdFilterProvider).search);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(herdFilterProvider);
    final herd = ref.watch(herdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search tag, name, breed', isDense: true),
                onSubmitted: (value) => ref.read(herdFilterProvider.notifier).setSearch(value),
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ACTIVE', label: Text('Active')),
                ButtonSegment(value: 'SOLD', label: Text('Sold')),
                ButtonSegment(value: 'DECEASED', label: Text('Deceased')),
                ButtonSegment(value: 'ALL', label: Text('All')),
              ],
              selected: {filter.status},
              onSelectionChanged: (selection) => ref.read(herdFilterProvider.notifier).setStatus(selection.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: herd.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load animals.'))),
            data: (animals) {
              if (animals.isEmpty) {
                return Center(
                  child: Text(filter.search.isEmpty && filter.status == 'ACTIVE' ? 'No animals yet. Add your first animal.' : 'No animals match.'),
                );
              }
              final now = DateTime.now();
              return ListView.separated(
                itemCount: animals.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => _AnimalTile(animal: animals[index], now: now),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AnimalTile extends StatelessWidget {
  const _AnimalTile({required this.animal, required this.now});

  final Animal animal;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final age = ageLabel(animal.dateOfBirth, now);
    final details = [
      humanizeEnum(animal.sex),
      ?animal.breed,
      ?age,
      if (animal.latestWeightKg != null) '${trimDecimal(animal.latestWeightKg!)} kg',
    ];
    return ListTile(
      leading: AnimalThumbnail(animal: animal),
      title: Text(animal.ref.label),
      subtitle: Text(details.join(' · ')),
      trailing: _StatusChip(animal: animal),
      onTap: () => context.go('/goat-farm/animals/${animal.id}'),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = animal.isActive ? humanizeEnum(animal.healthStatus) : humanizeEnum(animal.status);
    final warn = animal.isActive && animal.healthStatus != 'HEALTHY';
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: warn ? scheme.errorContainer : null,
    );
  }
}

class _BreedingTab extends ConsumerWidget {
  const _BreedingTab();

  Future<void> _setStatus(BuildContext context, WidgetRef ref, BreedingRecord record, String status) async {
    try {
      await ref.read(farmRepositoryProvider).updateBreedingStatus(requireWorkspaceIdFromWidget(ref), record.id, status);
      invalidateFarm(ref, animalId: record.dam.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not update the record.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breeding = ref.watch(breedingProvider);
    return breeding.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load breeding records.'))),
      data: (records) {
        if (records.isEmpty) return const Center(child: Text('No mating records yet.'));
        final now = DateTime.now();
        return ListView.separated(
          padding: const EdgeInsets.only(top: 8),
          itemCount: records.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final r = records[index];
            final subtitle = r.status == 'KIDDED'
                ? 'Kidded ${formatDate(r.kiddingDate!)} · ${r.kidsAlive ?? 0} alive of ${r.kidsBorn ?? 0}'
                : 'Mated ${formatDate(r.matingDate)} with ${r.sireLabel} · due ${formatDate(r.expectedKiddingDate)}'
                    '${r.isOpen ? ' (${dueLabel(r.expectedKiddingDate, now)})' : ''}';
            return ListTile(
              leading: const Icon(Icons.favorite_rounded),
              title: Text('${r.dam.label} · ${humanizeEnum(r.status)}'),
              subtitle: Text(subtitle),
              trailing: !r.isOpen
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: 'Update',
                      onSelected: (action) {
                        if (action == 'KIDDING') {
                          showDialog<bool>(context: context, builder: (_) => RecordKiddingDialog(record: r));
                        } else {
                          _setStatus(context, ref, r, action);
                        }
                      },
                      itemBuilder: (_) => [
                        if (r.status == 'MATED') const PopupMenuItem(value: 'PREGNANT', child: Text('Confirm pregnant')),
                        if (r.status == 'MATED') const PopupMenuItem(value: 'NOT_PREGNANT', child: Text('Not pregnant')),
                        const PopupMenuItem(value: 'KIDDING', child: Text('Record kidding')),
                        const PopupMenuItem(value: 'ABORTED', child: Text('Aborted')),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(farmOverviewProvider);
    final scheme = Theme.of(context).colorScheme;
    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load the schedule.'))),
      data: (o) {
        if (o.dueHealth.isEmpty && o.upcomingKiddings.isEmpty) {
          return const Center(child: Text('Nothing due in the next 30 days.'));
        }
        final now = DateTime.now();
        return ListView(
          padding: const EdgeInsets.only(top: 8),
          children: [
            if (o.dueHealth.isNotEmpty) ...[
              Text('Health follow-ups', style: Theme.of(context).textTheme.titleSmall),
              for (final item in o.dueHealth)
                ListTile(
                  leading: Icon(Icons.vaccines_rounded, color: item.overdue ? scheme.error : null),
                  title: Text('${humanizeEnum(item.type)} · ${item.animal.label}'),
                  subtitle: Text('${item.description} · ${formatDate(item.nextDueDate)}'),
                  trailing: Text(
                    dueLabel(item.nextDueDate, now),
                    style: TextStyle(color: item.overdue ? scheme.error : null, fontWeight: item.overdue ? FontWeight.w600 : null),
                  ),
                  onTap: () => context.go('/goat-farm/animals/${item.animal.id}'),
                ),
              const SizedBox(height: 12),
            ],
            if (o.upcomingKiddings.isNotEmpty) ...[
              Text('Expected kiddings', style: Theme.of(context).textTheme.titleSmall),
              for (final k in o.upcomingKiddings)
                ListTile(
                  leading: const Icon(Icons.child_friendly_rounded),
                  title: Text(k.dam.label),
                  subtitle: Text('${humanizeEnum(k.status)} · ${formatDate(k.expectedKiddingDate)}'),
                  trailing: Text(dueLabel(k.expectedKiddingDate, now)),
                  onTap: () => context.go('/goat-farm/animals/${k.dam.id}'),
                ),
            ],
          ],
        );
      },
    );
  }
}
