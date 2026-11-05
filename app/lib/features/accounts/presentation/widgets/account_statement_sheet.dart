import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/accounting/accounting_controller.dart';
import '../../../../core/accounting/accounting_models.dart';
import '../../../../core/accounting/money_format.dart';
import '../../../../core/api/api_error.dart';

/// Shows every posted line on this account, with a bank-reconciliation
/// checklist: tick a line off once it's matched against the real bank
/// statement (`JournalLine.reconciledAt` — previously tracked in the
/// schema/backups but nothing ever set it).
class AccountStatementSheet extends ConsumerStatefulWidget {
  const AccountStatementSheet({super.key, required this.account});
  final Account account;

  @override
  ConsumerState<AccountStatementSheet> createState() => _AccountStatementSheetState();
}

class _AccountStatementSheetState extends ConsumerState<AccountStatementSheet> {
  late Future<List<AccountStatementRow>> _future;
  List<AccountStatementRow> _rows = const [];
  final _pending = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final workspaceId = requireWorkspaceIdFromWidget(ref);
    _future = ref.read(accountingRepositoryProvider).getAccountStatement(workspaceId, widget.account.id)
      ..then((rows) {
        if (mounted) setState(() => _rows = rows);
      });
  }

  Future<void> _toggle(AccountStatementRow row) async {
    final workspaceId = requireWorkspaceIdFromWidget(ref);
    final target = !row.isReconciled;
    setState(() {
      _pending.add(row.id);
      _rows = [
        for (final r in _rows)
          if (r.id == row.id) AccountStatementRow(id: r.id, journalEntryId: r.journalEntryId, postedAt: r.postedAt, memo: r.memo, amount: r.amount, runningBalance: r.runningBalance, reconciledAt: target ? DateTime.now() : null) else r,
      ];
    });
    try {
      await ref.read(accountingRepositoryProvider).setLineReconciled(workspaceId, widget.account.id, row.id, target);
    } catch (error) {
      // Roll back on failure — never leave the UI claiming a state the server rejected.
      if (mounted) {
        setState(() {
          _rows = [for (final r in _rows) if (r.id == row.id) row else r];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error, 'Could not update reconciliation.'))));
      }
    } finally {
      if (mounted) setState(() => _pending.remove(row.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.account.code} · ${widget.account.name}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Statement', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<AccountStatementRow>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _rows.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError && _rows.isEmpty) {
                      return Center(child: Text('Could not load statement: ${snapshot.error}'));
                    }
                    if (_rows.isEmpty) {
                      return const Center(child: Text('No activity on this account yet.'));
                    }
                    final reconciledCount = _rows.where((r) => r.isReconciled).length;
                    final dateFormat = DateFormat.yMMMd();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$reconciledCount of ${_rows.length} reconciled',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: _rows.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final row = _rows[index];
                              return ListTile(
                                leading: _pending.contains(row.id)
                                    ? const SizedBox(width: 24, height: 24, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2)))
                                    : Checkbox(value: row.isReconciled, onChanged: (_) => _toggle(row)),
                                title: Text(row.memo ?? '—'),
                                subtitle: Text(dateFormat.format(row.postedAt)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(formatMoney(naturalBalance(row.amount, widget.account.type))),
                                    Text(
                                      'Bal: ${formatMoney(naturalBalance(row.runningBalance, widget.account.type))}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
