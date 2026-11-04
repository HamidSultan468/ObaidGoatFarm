import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/accounting/money_format.dart';

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
                  children: entries
                      .take(5)
                      .map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(entry.memo ?? entry.entryType),
                          subtitle: Text(entry.postedAt != null ? dateFormat.format(entry.postedAt!) : entry.status),
                          trailing: Text(formatMoney(entry.displayAmount), style: Theme.of(context).textTheme.titleSmall),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
