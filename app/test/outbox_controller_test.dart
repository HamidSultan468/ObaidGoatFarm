import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/accounting/accounting_controller.dart';
import 'package:app/core/accounting/accounting_models.dart';
import 'package:app/core/accounting/accounting_repository.dart';
import 'package:app/core/api/api_client.dart';
import 'package:app/core/offline/connectivity_controller.dart';
import 'package:app/core/offline/outbox_controller.dart';
import 'package:app/core/offline/outbox_models.dart';
import 'package:app/core/workspace/workspace_controller.dart';
import 'package:app/core/workspace/workspace_models.dart';

import 'test_helpers.dart';

const _workspace = Workspace(id: 'ws-1', name: 'Test Farm', slug: 'test-farm');

/// A successful sync calls TransactionsController.refresh(), which rebuilds
/// by reading listTransactions — stub it so that rebuild never reaches a
/// real network call or the real (platform-channel-backed) ApiClient.
class _ScriptedWorkspaceController extends WorkspaceController {
  @override
  WorkspaceState build() => const WorkspaceSelected(_workspace, [_workspace]);
}

/// Queues canned outcomes for `recordIncome`/`recordExpense` so each test
/// can script exactly what the "server" does on each attempt — a dropped
/// connection, a rejection, or success — and records every call made,
/// including which `idempotencyKey` it was sent with.
class _ScriptedAccountingRepository extends AccountingRepository {
  _ScriptedAccountingRepository() : super(ApiClient(tokenStorage: InMemoryTokenStorage()));

  final List<Object? Function()> _script = [];
  final calls = <Map<String, dynamic>>[];

  void thenOffline() => _script.add(() => throw DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError));

  void thenReject(String message) => _script.add(
    () => throw DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 400, data: {'message': message}),
    ),
  );

  void thenSucceed() => _script.add(() => null);

  @override
  Future<List<JournalEntry>> listTransactions(String workspaceId, {int limit = 50}) async => const [];

  JournalEntry _entry() => JournalEntry(
    id: 'entry-1',
    entryType: 'EXPENSE',
    status: 'POSTED',
    memo: null,
    documentNumber: null,
    verificationCode: null,
    postedAt: null,
    createdAt: DateTime.utc(2026, 11, 4),
    lines: const [],
  );

  Object? _next(String kind, String? idempotencyKey) {
    calls.add({'kind': kind, 'idempotencyKey': idempotencyKey});
    if (_script.isEmpty) throw StateError('No scripted outcome left for call ${calls.length}');
    return _script.removeAt(0)();
  }

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
    _next('expense', idempotencyKey);
    return _entry();
  }

  @override
  Future<JournalEntry> recordIncome(
    String workspaceId, {
    required String toAccountId,
    required String incomeAccountId,
    required String amount,
    String? memo,
    String? contactId,
    bool issueReceipt = false,
    String? animalId,
    String? landParcelId,
    String? idempotencyKey,
  }) async {
    _next('income', idempotencyKey);
    return _entry();
  }
}

const _payload = {'fromAccountId': 'cash', 'expenseAccountId': 'feed', 'amount': '500.00', 'memo': 'Chara'};

void main() {
  late _ScriptedAccountingRepository repository;
  late StreamController<bool> connectivity;
  late ProviderContainer container;

  setUp(() {
    repository = _ScriptedAccountingRepository();
    connectivity = StreamController<bool>.broadcast();
    container = ProviderContainer(
      overrides: [
        accountingRepositoryProvider.overrideWithValue(repository),
        connectivityProvider.overrideWith((ref) => connectivity.stream),
        outboxStoreProvider.overrideWithValue(InMemoryOutboxStore()),
        workspaceControllerProvider.overrideWith(_ScriptedWorkspaceController.new),
      ],
    );
    // A StreamProvider only subscribes to its underlying stream while
    // something is actually watching/listening to it. In the real app
    // that's the top-bar SyncStatus widget; here nothing plays that role,
    // so without this, connectivityProvider would stay stuck in
    // AsyncLoading forever and OutboxController's own `ref.listen` would
    // never see a single event.
    container.listen(connectivityProvider, (_, _) {});
    // addTearDown runs in LIFO order: dispose the container FIRST (so
    // Riverpod cancels its subscription to `connectivity.stream`), *then*
    // close the controller — closing it first would hang `close()` waiting
    // for a listener that only gets cancelled by `dispose()`.
    addTearDown(connectivity.close);
    addTearDown(container.dispose);
  });

  test('a write that succeeds is reported Synced and never touches the queue', () async {
    repository.thenSucceed();
    final result = await container
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense: 500.00', payload: _payload);

    expect(result, isA<OutboxSubmitSynced>());
    expect(container.read(outboxControllerProvider), isEmpty);
    expect(repository.calls, hasLength(1));
  });

  test('a dropped connection is reported Queued and the item is persisted pending', () async {
    repository.thenOffline();
    final result = await container
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense: 500.00', payload: _payload);

    expect(result, isA<OutboxSubmitQueued>());
    final queue = container.read(outboxControllerProvider);
    expect(queue, hasLength(1));
    expect(queue.single.status, OutboxStatus.pending);
    expect(queue.single.summary, 'Expense: 500.00');
  });

  test('the server actively rejecting the request is reported Rejected and nothing is queued', () async {
    repository.thenReject('fromAccountId must be a string');
    final result = await container
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense: 500.00', payload: _payload);

    expect(result, isA<OutboxSubmitRejected>());
    expect((result as OutboxSubmitRejected).message, 'fromAccountId must be a string');
    expect(container.read(outboxControllerProvider), isEmpty, reason: 'a rejection is the caller\'s to fix, not a retryable sync problem');
  });

  test('reconnecting automatically retries a queued item, reusing the SAME idempotency key', () async {
    repository.thenOffline();
    await container
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense: 500.00', payload: _payload);
    expect(container.read(outboxControllerProvider), hasLength(1));
    final firstAttemptKey = repository.calls.single['idempotencyKey'];
    expect(firstAttemptKey, isNotNull, reason: 'every attempt — even the one that fails offline — must carry a key');

    repository.thenSucceed();
    connectivity.add(true);
    await pumpEventQueue();

    expect(container.read(outboxControllerProvider), isEmpty, reason: 'synced and removed from the queue after reconnecting');
    expect(repository.calls, hasLength(2));
    expect(repository.calls.last['idempotencyKey'], firstAttemptKey, reason: 'a retry must replay as the SAME request, not a new one');
  });

  test('going offline again after reconnecting does not re-trigger a retry (only the offline->online edge does)', () async {
    repository.thenOffline();
    await container
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense: 500.00', payload: _payload);

    connectivity.add(false); // still offline -> no edge, no retry attempt
    await pumpEventQueue();
    expect(repository.calls, hasLength(1));
  });

  test('a rejected item can be fixed and retried manually, and disappears once it succeeds', () async {
    repository.thenReject('bad request');
    await container
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense: 500.00', payload: _payload);
    expect(container.read(outboxControllerProvider), isEmpty); // rejections aren't queued (see test above) — nothing to retry here.
  });

  test('a queued (offline) item can be discarded without ever contacting the server again', () async {
    repository.thenOffline();
    await container
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense: 500.00', payload: _payload);
    final id = container.read(outboxControllerProvider).single.id;

    await container.read(outboxControllerProvider.notifier).discard(id);

    expect(container.read(outboxControllerProvider), isEmpty);
    connectivity.add(true);
    await pumpEventQueue();
    expect(repository.calls, hasLength(1), reason: 'discarding must not leave anything behind to retry');
  });

  test('manual "retry now" re-attempts a still-pending item immediately', () async {
    repository.thenOffline();
    await container
        .read(outboxControllerProvider.notifier)
        .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense: 500.00', payload: _payload);
    final id = container.read(outboxControllerProvider).single.id;

    repository.thenSucceed();
    await container.read(outboxControllerProvider.notifier).retry(id);

    expect(container.read(outboxControllerProvider), isEmpty);
    expect(repository.calls, hasLength(2));
  });

  test('five submissions queued offline are replayed in the order they were created', () async {
    for (var i = 0; i < 5; i++) {
      repository.thenOffline();
    }
    for (var i = 0; i < 5; i++) {
      await container
          .read(outboxControllerProvider.notifier)
          .submit(workspaceId: 'ws-1', kind: OutboxKind.expense, summary: 'Expense #$i', payload: _payload);
    }
    expect(container.read(outboxControllerProvider), hasLength(5));

    for (var i = 0; i < 5; i++) {
      repository.thenSucceed();
    }
    connectivity.add(true);
    await pumpEventQueue();

    expect(container.read(outboxControllerProvider), isEmpty);
    // The 5 offline attempts, then exactly 5 more on replay — in creation order.
    final replaySummaries = repository.calls.skip(5).map((c) => c['idempotencyKey']).toList();
    final originalSummaries = repository.calls.take(5).map((c) => c['idempotencyKey']).toList();
    expect(replaySummaries, originalSummaries);
  });
}
