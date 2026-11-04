import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/accounting/accounting_models.dart';
import '../../../../core/accounting/money_format.dart';

class AccountStatementSheet extends ConsumerWidget {
  const AccountStatementSheet({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = requireWorkspaceIdFromWidget(ref);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${account.code} · ${account.name}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Statement', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<AccountStatementRow>>(
                  future: ref.read(accountingRepositoryProvider).getAccountStatement(workspaceId, account.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Could not load statement: ${snapshot.error}'));
                    }
                    final rows = snapshot.data ?? [];
                    if (rows.isEmpty) {
                      return const Center(child: Text('No activity on this account yet.'));
                    }
                    final dateFormat = DateFormat.yMMMd();
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return ListTile(
                          title: Text(row.memo ?? '—'),
                          subtitle: Text(dateFormat.format(row.postedAt)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatMoney(naturalBalance(row.amount, account.type))),
                              Text(
                                'Bal: ${formatMoney(naturalBalance(row.runningBalance, account.type))}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
