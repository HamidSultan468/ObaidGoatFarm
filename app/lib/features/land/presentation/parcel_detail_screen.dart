import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/accounting/accounting_controller.dart';
import '../../../core/accounting/money_format.dart';
import '../../../core/api/api_error.dart';
import '../../../core/farm/farm_format.dart';
import '../../../core/land/land.dart';
import '../../documents/presentation/widgets/attachments_card.dart';
import 'widgets/add_parcel_dialog.dart' show EditParcelDialog;

class ParcelDetailScreen extends ConsumerWidget {
  const ParcelDetailScreen({super.key, required this.parcelId});
  final String parcelId;

  Future<void> _setStatus(BuildContext context, WidgetRef ref, LandParcel parcel, String status) async {
    try {
      await ref
          .read(landRepositoryProvider)
          .update(requireWorkspaceIdFromWidget(ref), parcel.id, {'status': status}, ifMatch: parcel.updatedAt);
      invalidateLand(ref, parcelId: parcel.id);
    } on DioException catch (error) {
      if (!context.mounted) return;
      invalidateLand(ref, parcelId: parcel.id);
      final message = error.response?.statusCode == 412
          ? 'Someone else updated this land record just now. Reloaded the latest — please try again.'
          : apiErrorMessage(error, 'Could not update the status.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not update the status.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelAsync = ref.watch(landParcelProvider(parcelId));
    return parcelAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(apiErrorMessage(error, 'Could not load this land record.')),
            TextButton(onPressed: () => context.go('/land'), child: const Text('Back to land')),
          ],
        ),
      ),
      data: (p) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              IconButton(tooltip: 'Back to land', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/land')),
              const SizedBox(width: 8),
              Expanded(child: Text(p.name, style: Theme.of(context).textTheme.headlineSmall, overflow: TextOverflow.ellipsis)),
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => showDialog<bool>(context: context, builder: (_) => EditParcelDialog(parcel: p)),
              ),
              PopupMenuButton<String>(
                tooltip: 'Change status',
                onSelected: (status) => _setStatus(context, ref, p, status),
                itemBuilder: (_) => [
                  for (final s in const ['ACTIVE', 'LEASE_ENDED', 'SOLD'])
                    if (s != p.status) PopupMenuItem(value: s, child: Text('Mark ${humanizeEnum(s).toLowerCase()}')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [Chip(label: Text(humanizeEnum(p.status))), Chip(label: Text(humanizeEnum(p.tenure)))]),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final left = [_DetailsCard(parcel: p), _AreaCard(parcel: p)];
              final right = [_FinanceCard(parcelId: p.id), AttachmentsCard(module: 'LAND', recordId: p.id)];
              if (constraints.maxWidth < 900) return Column(children: [...left, ...right]);
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
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8), ...children],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.parcel});
  final LandParcel parcel;

  @override
  Widget build(BuildContext context) {
    final p = parcel;
    return _Card(
      title: 'Details',
      children: [
        if (p.location != null) _Row('Location', p.location!),
        if (p.surveyNumber != null) _Row('Khasra / survey no.', p.surveyNumber!),
        if (p.ownerName != null) _Row('Owner', p.ownerName!),
        if (p.landUse != null) _Row('Land use', p.landUse!),
        if (p.acquisitionDate != null) _Row('Acquired', formatDate(p.acquisitionDate!)),
        if (p.isLeased) ...[
          if (p.counterpartyName != null) _Row(p.tenure == 'LEASED_IN' ? 'Landlord' : 'Tenant', p.counterpartyName!),
          if (p.leaseStartDate != null || p.leaseEndDate != null)
            _Row('Lease period', '${p.leaseStartDate != null ? formatDate(p.leaseStartDate!) : '?'} – ${p.leaseEndDate != null ? formatDate(p.leaseEndDate!) : '?'}'),
          if (p.leaseTerms != null) _Row('Lease terms', p.leaseTerms!),
        ],
        if (p.notes != null) _Row('Notes', p.notes!),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.parcel});
  final LandParcel parcel;

  @override
  Widget build(BuildContext context) {
    final p = parcel;
    return _Card(
      title: 'Area',
      children: [
        _Row('As recorded', '${trimDecimal(p.areaValue)} ${humanizeEnum(p.areaUnit).toLowerCase()}'),
        _Row('Breakdown', p.areaBreakdown.label),
        const Divider(),
        for (final unit in areaUnits)
          if (unit != p.areaUnit && p.areaConversions[unit] != null)
            _Row(humanizeEnum(unit), trimDecimal(p.areaConversions[unit]!)),
        const SizedBox(height: 4),
        Text('Marla = 272.25 sq ft (revenue standard).', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FinanceCard extends ConsumerWidget {
  const _FinanceCard({required this.parcelId});
  final String parcelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(landLedgerProvider(parcelId));
    return _Card(
      title: 'Finances',
      children: [
        ledger.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(apiErrorMessage(error, 'Could not load finances.')),
          data: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Row('Income', formatMoney(p.income)),
              _Row('Expenses', formatMoney(p.expense)),
              _Row('Net', formatMoney(p.net)),
              const SizedBox(height: 4),
              Text(
                'Crop sales, rent, labor, irrigation, fertilizer: record them in Bank & Accounts and choose this land.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
