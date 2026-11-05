import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/accounting/accounting_controller.dart';
import '../../../core/accounting/accounting_models.dart';
import '../../../core/accounting/money_format.dart';
import 'widgets/account_statement_sheet.dart';
import 'widgets/budgets_tab.dart';
import 'widgets/create_account_dialog.dart';
import 'widgets/record_transaction_dialog.dart';
import 'widgets/recurring_templates_tab.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsControllerProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Bank & Accounts', style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showDialog<void>(context: context, builder: (_) => const CreateAccountDialog()),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add account'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const TabBar(
                isScrollable: true,
                tabs: [Tab(text: 'Accounts'), Tab(text: 'Budgets'), Tab(text: 'Recurring')],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    accountsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('Could not load accounts: $error')),
                      data: (accounts) => _AccountsList(accounts: accounts),
                    ),
                    const BudgetsTab(),
                    const RecurringTemplatesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: PopupMenuButton<String>(
          icon: const Icon(Icons.add_circle_rounded, size: 48),
          tooltip: 'Record a transaction',
          onSelected: (value) {
            switch (value) {
              case 'income':
                showDialog<void>(context: context, builder: (_) => const RecordTransactionDialog(kind: TransactionKind.income));
              case 'expense':
                showDialog<void>(context: context, builder: (_) => const RecordTransactionDialog(kind: TransactionKind.expense));
              case 'transfer':
                showDialog<void>(context: context, builder: (_) => const RecordTransactionDialog(kind: TransactionKind.transfer));
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'income', child: Text('Record income')),
            PopupMenuItem(value: 'expense', child: Text('Record expense')),
            PopupMenuItem(value: 'transfer', child: Text('Transfer between accounts')),
          ],
        ),
      ),
    );
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({required this.accounts});
  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Center(child: Text('No accounts yet.'));
    }

    final byType = <String, List<Account>>{};
    for (final account in accounts) {
      byType.putIfAbsent(account.type, () => []).add(account);
    }

    return ListView(
      children: byType.entries.map((entry) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
              ),
              ...entry.value.map(
                (account) => _AccountTile(account: account),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = requireWorkspaceIdFromWidget(ref);
    return FutureBuilder<String>(
      future: ref.read(accountingRepositoryProvider).getAccountBalance(workspaceId, account.id),
      builder: (context, snapshot) {
        return ListTile(
          leading: Icon(_iconFor(account.kind)),
          title: Text('${account.code} · ${account.name}'),
          subtitle: account.isSystemAccount ? const Text('System account') : null,
          trailing: snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(
                  snapshot.data != null ? formatMoney(naturalBalance(snapshot.data!, account.type)) : '—',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => AccountStatementSheet(account: account),
          ),
        );
      },
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'CASH':
        return Icons.payments_rounded;
      case 'BANK':
        return Icons.account_balance_rounded;
      case 'RECEIVABLE':
        return Icons.call_received_rounded;
      case 'PAYABLE':
        return Icons.call_made_rounded;
      default:
        return Icons.folder_rounded;
    }
  }
}
