import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accounting/money_format.dart';
import '../../../core/api/api_error.dart';
import '../../../core/farm/farm_format.dart';
import '../../../core/land/land.dart';
import 'widgets/add_parcel_dialog.dart';

class LandScreen extends ConsumerWidget {
  const LandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcels = ref.watch(landParcelsProvider);
    final report = ref.watch(landProfitReportProvider).value;
    final status = ref.watch(landStatusFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Land Records', style: Theme.of(context).textTheme.headlineSmall),
              FilledButton.icon(
                onPressed: () => showDialog<bool>(context: context, builder: (_) => const AddParcelDialog()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add land'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report != null)
            Text(
              'All land: income ${formatMoney(report.total.income)} · expenses ${formatMoney(report.total.expense)} · net ${formatMoney(report.total.net)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ACTIVE', label: Text('Active')),
                ButtonSegment(value: 'LEASE_ENDED', label: Text('Lease ended')),
                ButtonSegment(value: 'SOLD', label: Text('Sold')),
                ButtonSegment(value: 'ALL', label: Text('All')),
              ],
              selected: {status},
              onSelectionChanged: (s) => ref.read(landStatusFilterProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: parcels.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(apiErrorMessage(error, 'Could not load land records.'))),
              data: (list) {
                if (list.isEmpty) {
                  return Center(child: Text(status == 'ACTIVE' ? 'No land recorded yet. Add your first field or plot.' : 'No land matches.'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = list[index];
                    final net = report?.rows[p.id]?.net;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.landscape_rounded)),
                      title: Text(p.name),
                      subtitle: Text([
                        p.areaBreakdown.label,
                        humanizeEnum(p.tenure),
                        ?p.location,
                        ?p.landUse,
                      ].join(' · ')),
                      trailing: net == null ? null : Text('Net ${formatMoney(net)}', style: Theme.of(context).textTheme.titleSmall),
                      onTap: () => context.go('/land/parcels/${p.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
