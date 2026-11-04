import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../workspace/workspace_controller.dart';
import '../workspace/workspace_models.dart';
import 'accounting_models.dart';
import 'accounting_repository.dart';

final accountingRepositoryProvider = Provider<AccountingRepository>(
  (ref) => AccountingRepository(ref.watch(apiClientProvider)),
);

/// Throws if no workspace is selected yet — every screen that reads this
/// must only be reachable once one exists (the router already guarantees this).
String _workspaceIdFromState(WorkspaceState state) {
  if (state is WorkspaceSelected) return state.workspace.id;
  throw StateError('No workspace selected');
}

/// For use inside Notifier/Provider bodies (which receive a `Ref`).
String requireWorkspaceId(Ref ref) => _workspaceIdFromState(ref.watch(workspaceControllerProvider));

/// For use inside widget `build(context, ref)` methods (which receive a
/// `WidgetRef` — a distinct type from `Ref` in Riverpod, not a subtype).
String requireWorkspaceIdFromWidget(WidgetRef ref) => _workspaceIdFromState(ref.watch(workspaceControllerProvider));

final accountsControllerProvider = AsyncNotifierProvider<AccountsController, List<Account>>(AccountsController.new);

class AccountsController extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() {
    final workspaceId = requireWorkspaceId(ref);
    return ref.read(accountingRepositoryProvider).listAccounts(workspaceId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> create({required String code, required String name, required String type}) async {
    final workspaceId = requireWorkspaceId(ref);
    await ref.read(accountingRepositoryProvider).createAccount(workspaceId, code: code, name: name, type: type);
    await refresh();
  }
}

final contactsControllerProvider = AsyncNotifierProvider<ContactsController, List<Contact>>(ContactsController.new);

class ContactsController extends AsyncNotifier<List<Contact>> {
  @override
  Future<List<Contact>> build() {
    final workspaceId = requireWorkspaceId(ref);
    return ref.read(accountingRepositoryProvider).listContacts(workspaceId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> create({required String type, required String name, String? email, String? phone}) async {
    final workspaceId = requireWorkspaceId(ref);
    await ref.read(accountingRepositoryProvider).createContact(workspaceId, type: type, name: name, email: email, phone: phone);
    await refresh();
  }
}

final transactionsControllerProvider =
    AsyncNotifierProvider<TransactionsController, List<JournalEntry>>(TransactionsController.new);

class TransactionsController extends AsyncNotifier<List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> build() {
    final workspaceId = requireWorkspaceId(ref);
    return ref.read(accountingRepositoryProvider).listTransactions(workspaceId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
    // Account balances and reports change whenever a transaction posts.
    ref.invalidate(accountsControllerProvider);
    ref.invalidate(profitAndLossProvider);
    ref.invalidate(liquidBalanceProvider);
  }

  Future<void> recordIncome({
    required String toAccountId,
    required String incomeAccountId,
    required String amount,
    String? memo,
    String? contactId,
    bool issueReceipt = false,
    String? animalId,
    String? landParcelId,
  }) async {
    final workspaceId = requireWorkspaceId(ref);
    await ref
        .read(accountingRepositoryProvider)
        .recordIncome(
          workspaceId,
          toAccountId: toAccountId,
          incomeAccountId: incomeAccountId,
          amount: amount,
          memo: memo,
          contactId: contactId,
          animalId: animalId,
          landParcelId: landParcelId,
          issueReceipt: issueReceipt,
        );
    await refresh();
  }

  Future<void> recordExpense({
    required String fromAccountId,
    required String expenseAccountId,
    required String amount,
    String? memo,
    String? contactId,
    String? animalId,
    String? landParcelId,
  }) async {
    final workspaceId = requireWorkspaceId(ref);
    await ref
        .read(accountingRepositoryProvider)
        .recordExpense(
          workspaceId,
          fromAccountId: fromAccountId,
          expenseAccountId: expenseAccountId,
          amount: amount,
          memo: memo,
          contactId: contactId,
          animalId: animalId,
          landParcelId: landParcelId,
        );
    await refresh();
  }

  Future<void> recordTransfer({
    required String fromAccountId,
    required String toAccountId,
    required String amount,
    String? memo,
  }) async {
    final workspaceId = requireWorkspaceId(ref);
    await ref
        .read(accountingRepositoryProvider)
        .recordTransfer(workspaceId, fromAccountId: fromAccountId, toAccountId: toAccountId, amount: amount, memo: memo);
    await refresh();
  }
}

final profitAndLossProvider = FutureProvider<ProfitAndLossReport>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  // Re-fetch whenever a transaction is recorded (see TransactionsController.refresh).
  return ref.watch(accountingRepositoryProvider).getProfitAndLoss(workspaceId);
});

final liquidBalanceProvider = FutureProvider<String>((ref) {
  final workspaceId = requireWorkspaceId(ref);
  return ref.watch(accountingRepositoryProvider).getLiquidBalance(workspaceId);
});
