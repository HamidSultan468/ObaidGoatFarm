import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/accounting/accounting_controller.dart';
import 'package:app/core/accounting/accounting_models.dart';
import 'package:app/core/accounting/accounting_repository.dart';
import 'package:app/core/ai/ai.dart';
import 'package:app/core/api/api_client.dart';
import 'package:app/core/farm/farm_controller.dart';
import 'package:app/core/farm/farm_models.dart';
import 'package:app/core/land/land.dart';
import 'package:app/core/workspace/workspace_controller.dart';
import 'package:app/core/workspace/workspace_models.dart';
import 'package:app/features/ai_assistant/presentation/widgets/draft_review_card.dart';

import 'test_helpers.dart';

const _workspace = Workspace(id: 'ws-1', name: 'Farm', slug: 'farm', myRole: 'OWNER');

class _FakeWorkspaceController extends WorkspaceController {
  @override
  WorkspaceState build() => const WorkspaceSelected(_workspace, [_workspace]);
}

class _FakeAccountingRepository extends AccountingRepository {
  _FakeAccountingRepository() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));

  @override
  Future<List<Account>> listAccounts(String workspaceId) async => const [
    Account(id: 'cash', code: '1000', name: 'Cash', type: 'ASSET', kind: 'CASH', isSystemAccount: true, isActive: true),
    Account(id: 'feed', code: '5100', name: 'Feed', type: 'EXPENSE', kind: 'GENERAL', isSystemAccount: false, isActive: true),
    Account(id: 'sales', code: '4000', name: 'Sales Income', type: 'INCOME', kind: 'GENERAL', isSystemAccount: true, isActive: true),
  ];

  @override
  Future<List<JournalEntry>> listTransactions(String workspaceId, {int limit = 50}) async => [];
}

class _FakeAiRepository extends AiRepository {
  _FakeAiRepository({this.failWith}) : super(ApiClient(tokenStorage: InMemoryTokenStorage()));
  final String? failWith;
  final approved = <Map<String, dynamic>>[];
  final rejected = <String>[];

  @override
  Future<void> approve(String ws, String id, Map<String, dynamic> payload) async {
    if (failWith != null) {
      final request = RequestOptions(path: '/approve');
      throw DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 400, data: {'message': failWith, 'details': ['expenseAccountId must be a string']}),
      );
    }
    approved.add(payload);
  }

  @override
  Future<void> reject(String ws, String id, {String? reason}) async => rejected.add(id);

  @override
  Future<List<RecordDraft>> drafts(String ws, String status) async => [];
}

final _expenseDraft = RecordDraft.fromJson({
  'id': 'd1',
  'source': 'AI_TEXT',
  'kind': 'EXPENSE',
  'status': 'PENDING',
  'summary': 'Bought feed for 5,000',
  'payload': {'amount': '5000', 'fromAccountId': 'cash', 'expenseAccountId': null, 'memo': 'chara'},
  'warnings': ['Choose a category'],
  'rawInput': 'chara 5000 ka liya',
  'createdAt': '2026-11-04T06:00:00.000Z',
});

Future<void> _pump(WidgetTester tester, _FakeAiRepository ai) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiRepositoryProvider.overrideWithValue(ai),
        accountingRepositoryProvider.overrideWithValue(_FakeAccountingRepository()),
        workspaceControllerProvider.overrideWith(_FakeWorkspaceController.new),
        allAnimalsProvider.overrideWith((ref) async => const <Animal>[]),
        allLandParcelsProvider.overrideWith((ref) async => const <LandParcel>[]),
      ],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DraftReviewCard(draft: _expenseDraft)))),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the warnings and approves the reviewer\'s edited values', (tester) async {
    final ai = _FakeAiRepository();
    await _pump(tester, ai);

    expect(find.text('Choose a category'), findsOneWidget);
    expect(find.text('“chara 5000 ka liya”'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '5250.50');
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5100 · Feed').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve & save'));
    await tester.pumpAndSettle();

    expect(ai.approved.single, {'amount': '5250.50', 'fromAccountId': 'cash', 'expenseAccountId': 'feed', 'memo': 'chara'});
  });

  testWidgets('a server rejection is shown on the card, nothing is approved', (tester) async {
    final ai = _FakeAiRepository(failWith: 'The draft is incomplete or invalid.');
    await _pump(tester, ai);

    await tester.tap(find.text('Approve & save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('The draft is incomplete or invalid.'), findsOneWidget);
    expect(find.textContaining('expenseAccountId must be a string'), findsOneWidget);
    expect(ai.approved, isEmpty);
  });

  testWidgets('reject calls the API', (tester) async {
    final ai = _FakeAiRepository();
    await _pump(tester, ai);
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(ai.rejected, ['d1']);
  });
}
