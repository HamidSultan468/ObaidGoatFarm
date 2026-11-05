import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/accounting/accounting_models.dart';
import '../../../../core/accounting/money_format.dart';
import '../../../../core/farm/farm_format.dart' show humanizeEnum;

class RecentTransactionsCard extends ConsumerWidget {
  const RecentTransactionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium)),
                TextButton(onPressed: () => context.go('/accounts'), child: const Text('View all')),
              ],
            ),
            const SizedBox(height: 4),
            transactionsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (error, _) => Text('Could not load transactions.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No transactions recorded yet.'),
                  );
                }
                final dateFormat = DateFormat.MMMd();
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 56, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          Expanded(child: Text('Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          Text('Amount', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    for (final entry in entries.take(5)) _TransactionRow(entry: entry, dateFormat: dateFormat),
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

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.entry, required this.dateFormat});
  final JournalEntry entry;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.entryType == 'INCOME';
    final isExpense = entry.entryType == 'EXPENSE';
    final color = isIncome ? const Color(0xFF22A559) : (isExpense ? const Color(0xFFE5484D) : null);
    final sign = isIncome ? '+' : (isExpense ? '-' : '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(entry.postedAt != null ? dateFormat.format(entry.postedAt!) : '—', style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(entry.memo ?? humanizeEnum(entry.entryType), overflow: TextOverflow.ellipsis),
          ),
          Text('$sign${formatMoney(entry.displayAmount)}', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
