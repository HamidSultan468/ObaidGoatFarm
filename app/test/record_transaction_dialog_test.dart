import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/accounting/accounting_controller.dart';
import 'package:app/core/accounting/accounting_models.dart';
import 'package:app/core/accounting/accounting_repository.dart';
import 'package:app/core/api/api_client.dart';
import 'package:app/core/farm/farm_controller.dart';
import 'package:app/core/farm/farm_models.dart';
import 'package:app/core/land/land.dart';
import 'package:app/core/offline/connectivity_controller.dart';
import 'package:app/core/offline/outbox_controller.dart';
import 'package:app/core/workspace/workspace_controller.dart';
import 'package:app/core/workspace/workspace_models.dart';
import 'package:app/features/accounts/presentation/widgets/record_transaction_dialog.dart';

import 'test_helpers.dart';

const _workspace = Workspace(id: 'ws-1', name: 'Test Farm', slug: 'test-farm');

class _FakeWorkspaceController extends WorkspaceController {
  @override
  WorkspaceState build() => const WorkspaceSelected(_workspace, [_workspace]);
}

class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));

  final List<Map<String, String?>> recordedExpenses = [];

  static const accounts = [
    Account(id: 'cash', code: '1000', name: 'Cash', type: 'ASSET', kind: 'CASH', isSystemAccount: true, isActive: true),
    Account(id: 'bank', code: '1010', name: 'Bank Account', type: 'ASSET', kind: 'BANK', isSystemAccount: true, isActive: true),
    Account(id: 'sales', code: '4000', name: 'Sales Income', type: 'INCOME', kind: 'GENERAL', isSystemAccount: true, isActive: true),
    Account(id: 'expense', code: '5000', name: 'General Expense', type: 'EXPENSE', kind: 'GENERAL', isSystemAccount: true, isActive: true),
  ];

  @override
  Future<List<Account>> listAccounts(String workspaceId) async => accounts;

  @override
  Future<List<JournalEntry>> listTransactions(String workspaceId, {int limit = 50}) async => [];

  @override
  Future<JournalEntry> recordExpense(
    String workspaceId, {
    required String fromAccountId,
    required String expenseAccountId,
    required String amount,
    String? memo,
    String? contactId,
    String? animalId,
    String? landParcelId,
    String? idempotencyKey,
  }) async {
    recordedExpenses.add({
      'workspaceId': workspaceId,
      'fromAccountId': fromAccountId,
      'expenseAccountId': expenseAccountId,
      'amount': amount,
      'memo': memo,
      'animalId': animalId,
      'landParcelId': landParcelId,
    });
    return JournalEntry(
      id: 'entry-1',
      entryType: 'EXPENSE',
      status: 'POSTED',
      memo: memo,
      documentNumber: null,
      verificationCode: null,
      postedAt: DateTime(2026, 11, 4),
      createdAt: DateTime(2026, 11, 4),
      lines: const [],
    );
  }
}

Future<_FakeAccountingRepository> _openExpenseDialog(WidgetTester tester) async {
  final repository = _FakeAccountingRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountingRepositoryProvider.overrideWithValue(repository),
        workspaceControllerProvider.overrideWith(_FakeWorkspaceController.new),
        allAnimalsProvider.overrideWith((ref) async => const <Animal>[]),
        allLandParcelsProvider.overrideWith((ref) async => const <LandParcel>[]),
        connectivityProvider.overrideWith((ref) => Stream.value(true)),
        outboxStoreProvider.overrideWithValue(InMemoryOutboxStore()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const RecordTransactionDialog(kind: TransactionKind.expense),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _pick(WidgetTester tester, String fieldLabel, String itemText) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, fieldLabel));
  await tester.pumpAndSettle();
  // DropdownButton keeps every item in an IndexedStack for sizing; the open
  // menu's copy is the last match in the tree.
  await tester.tap(find.text(itemText).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('posting an expense sends the chosen accounts and amount, then closes', (tester) async {
    final repository = await _openExpenseDialog(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '750.00');
    await _pick(tester, 'Paid from', '1000 · Cash');
    await _pick(tester, 'Category', '5000 · General Expense');
    await tester.enterText(find.widgetWithText(TextField, 'Memo (optional)'), 'Vet visit');

    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(repository.recordedExpenses, [
      {
        'workspaceId': 'ws-1',
        'fromAccountId': 'cash',
        'expenseAccountId': 'expense',
        'amount': '750.00',
        'memo': 'Vet visit',
        'animalId': null,
        'landParcelId': null,
      },
    ]);
    expect(find.byType(RecordTransactionDialog), findsNothing);
  });

  testWidgets('posting with missing fields shows an error and makes no API call', (tester) async {
    final repository = await _openExpenseDialog(tester);

    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(find.text('Fill in all required fields.'), findsOneWidget);
    expect(repository.recordedExpenses, isEmpty);
    expect(find.byType(RecordTransactionDialog), findsOneWidget);
  });

  testWidgets('the expense category list offers only EXPENSE accounts', (tester) async {
    await _openExpenseDialog(tester);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Category'));
    await tester.pumpAndSettle();

    expect(find.text('5000 · General Expense'), findsWidgets);
    expect(find.text('4000 · Sales Income'), findsNothing);
  });
}
