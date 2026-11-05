import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/accounting/money_format.dart';
import '../../../../core/farm/farm_format.dart';
import '../../../../core/land/land.dart';

/// Dashboard widget: live parcel counts, tenure breakdown, net P&L, and
/// upcoming lease expirations — the Land Records equivalent of
/// [GoatFarmCard]. The backend's land list/profitability routes have no
/// role restriction beyond workspace membership (`land.controller.ts`), so
/// this card is shown to every member, same as GoatFarmCard.
class LandRecordsCard extends ConsumerWidget {
  const LandRecordsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelsAsync = ref.watch(landParcelsProvider);
    final reportAsync = ref.watch(landProfitReportProvider);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.landscape_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Land Records', style: Theme.of(context).textTheme.titleMedium)),
                TextButton(onPressed: () => context.go('/land'), child: const Text('Open')),
              ],
            ),
            const SizedBox(height: 4),
            parcelsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (error, _) => Text('Could not load land data.', style: TextStyle(color: scheme.error)),
              data: (parcels) {
                final owned = parcels.where((p) => !p.isLeased).length;
                final leased = parcels.length - owned;
                final now = DateTime.now();
                final upcomingLeaseEnds =
                    parcels.where((p) => p.leaseEndDate != null && p.leaseEndDate!.difference(now).inDays <= 60).toList()
                      ..sort((a, b) => a.leaseEndDate!.compareTo(b.leaseEndDate!));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _Stat(label: 'Parcels', value: '${parcels.length}', color: scheme.primary)),
                        Expanded(child: _Stat(label: 'Owned', value: '$owned', color: const Color(0xFF22A559))),
                        Expanded(child: _Stat(label: 'Leased', value: '$leased', color: const Color(0xFFF59E0B))),
                        Expanded(
                          child: reportAsync.when(
                            loading: () => const _Stat(label: 'Net P&L', value: '—', color: Colors.grey),
                            error: (_, _) => const _Stat(label: 'Net P&L', value: '—', color: Colors.grey),
                            data: (r) => _Stat(label: 'Net P&L', value: '\$${formatMoney(r.total.net)}', color: const Color(0xFF3B82F6)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (parcels.isEmpty)
                      Text('No parcels yet.', style: Theme.of(context).textTheme.bodySmall)
                    else if (upcomingLeaseEnds.isEmpty)
                      Text('No lease expiring in the next 60 days.', style: Theme.of(context).textTheme.bodySmall)
                    else
                      for (final parcel in upcomingLeaseEnds.take(4))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('Lease ends · ${parcel.name}', overflow: TextOverflow.ellipsis),
                          trailing: Text(
                            dueLabel(parcel.leaseEndDate!, now),
                            style: TextStyle(color: parcel.leaseEndDate!.isBefore(now) ? scheme.error : null),
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
