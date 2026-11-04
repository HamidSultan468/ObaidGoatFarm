import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../accounting/accounting_controller.dart';
import '../farm/farm_controller.dart';
import 'connectivity_controller.dart';
import 'outbox_models.dart';
import 'outbox_store.dart';

/// A random id that is also a valid Idempotency-Key for the backend
/// (8-100 of `[A-Za-z0-9_-]` — see backend `IDEMPOTENCY_KEY_PATTERN`):
/// 26 random bytes, hex-encoded, prefixed so it reads as what it is in
/// logs. No external uuid dependency needed for something this simple.
String _newOutboxId() {
  final random = Random.secure();
  final bytes = List<int>.generate(26, (_) => random.nextInt(256));
  return 'ob-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

/// Result of [OutboxController.submit] — what the calling dialog should do.
sealed class OutboxSubmitResult {
  const OutboxSubmitResult();
}

/// Sent immediately; behaves exactly like the old direct-call path.
class OutboxSubmitSynced extends OutboxSubmitResult {
  const OutboxSubmitSynced();
}

/// Could not reach the server right now; saved locally and will send
/// automatically once the app is back online.
class OutboxSubmitQueued extends OutboxSubmitResult {
  const OutboxSubmitQueued();
}

/// The server rejected the request outright (validation, permissions, a
/// business rule). Nothing was queued — the caller should show
/// [message] so the user can correct the input, same as before offline
/// support existed.
class OutboxSubmitRejected extends OutboxSubmitResult {
  const OutboxSubmitRejected(this.message);
  final String message;
}

final outboxStoreProvider = Provider<OutboxStore>((ref) => SecureOutboxStore());

final outboxControllerProvider = NotifierProvider<OutboxController, List<OutboxItem>>(OutboxController.new);

/// Owns the write queue: persists it, attempts each item against the real
/// backend with its stable Idempotency-Key, and retries automatically when
/// connectivity returns. See DECISIONS.md D037/D038 for the design.
///
/// Scope, deliberately: this is a *write* queue, not an offline read cache.
/// Lists (transactions, animals, ...) still come straight from the API and
/// will not show a queued item until it has actually synced — attempting to
/// merge unsynced drafts into those lists would risk showing a financial
/// total that doesn't match what the server holds. The pending-items badge
/// (see widgets/sync_status.dart) is how the user sees "this hasn't synced
/// yet" instead.
class OutboxController extends Notifier<List<OutboxItem>> {
  bool _processing = false;

  @override
  List<OutboxItem> build() {
    // ref.listen (rather than subscribing to the stream by hand) ties the
    // listener's lifetime to this Notifier automatically — no manual
    // cancellation needed. Retries on the transition *into* "online" only.
    ref.listen(connectivityProvider, (previous, next) {
      final wasOnline = previous?.value ?? false;
      final isOnline = next.value ?? false;
      if (isOnline && !wasOnline) unawaited(processQueue());
    });
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    state = await ref.read(outboxStoreProvider).load();
    if (state.any((i) => i.status == OutboxStatus.pending)) {
      unawaited(processQueue());
    }
  }

  Future<void> _persist() => ref.read(outboxStoreProvider).save(state);

  /// A synced transaction makes the transactions list, account balances
  /// and reports stale. A plain invalidate (not `TransactionsController.
  /// refresh()`'s eager `await future` rebuild) is deliberate here: this
  /// runs from a background sync with nothing necessarily watching these
  /// screens right now, so there is no reason to force an immediate
  /// re-fetch — the next widget that watches one of them will trigger it.
  void _invalidateTransactions() {
    ref.invalidate(transactionsControllerProvider);
    ref.invalidate(accountsControllerProvider);
    ref.invalidate(profitAndLossProvider);
    ref.invalidate(liquidBalanceProvider);
  }

  /// Attempts the write now. Returns [OutboxSubmitSynced] on success,
  /// [OutboxSubmitQueued] if it could not reach the server (queued for
  /// later), or [OutboxSubmitRejected] if the server actively refused it.
  Future<OutboxSubmitResult> submit({
    required String workspaceId,
    required OutboxKind kind,
    required String summary,
    required Map<String, dynamic> payload,
    String? animalId,
  }) async {
    final item = OutboxItem(
      id: _newOutboxId(),
      workspaceId: workspaceId,
      kind: kind,
      summary: summary,
      payload: payload,
      createdAt: DateTime.now().toUtc(),
      animalId: animalId,
    );
    final outcome = await _attempt(item);
    switch (outcome) {
      case _AttemptSynced():
        return const OutboxSubmitSynced();
      case _AttemptOffline():
        state = [...state, item.copyWith(lastError: outcome.message)];
        await _persist();
        return const OutboxSubmitQueued();
      case _AttemptRejected():
        return OutboxSubmitRejected(outcome.message);
    }
  }

  /// Re-attempts every pending item, in the order it was created, stopping
  /// at the first sign the server still isn't reachable (no point hammering
  /// through the rest of the queue one by one in that case — the next
  /// connectivity change or manual "Sync now" will try again).
  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      for (final item in List<OutboxItem>.of(state)) {
        if (item.status != OutboxStatus.pending) continue;
        _setItem(item.copyWith(status: OutboxStatus.sending));
        final outcome = await _attempt(item);
        switch (outcome) {
          case _AttemptSynced():
            _removeItem(item.id);
            await _persist();
          case _AttemptOffline():
            _setItem(item.copyWith(status: OutboxStatus.pending, lastError: outcome.message, attempts: item.attempts + 1));
            await _persist();
            return; // still offline — the rest will fail the same way right now.
          case _AttemptRejected():
            _setItem(item.copyWith(status: OutboxStatus.failed, lastError: outcome.message, attempts: item.attempts + 1));
            await _persist();
        }
      }
    } finally {
      _processing = false;
    }
  }

  /// Manual retry for one failed (or still-pending) item, e.g. from the
  /// outbox screen after fixing whatever the server rejected isn't
  /// possible in-place — mostly useful to re-check a pending item sooner
  /// than the next automatic trigger.
  Future<void> retry(String id) async {
    final item = state.firstWhere((i) => i.id == id, orElse: () => throw StateError('Outbox item $id not found'));
    _setItem(item.copyWith(status: OutboxStatus.sending));
    final outcome = await _attempt(item);
    switch (outcome) {
      case _AttemptSynced():
        _removeItem(id);
      case _AttemptOffline():
        _setItem(item.copyWith(status: OutboxStatus.pending, lastError: outcome.message, attempts: item.attempts + 1));
      case _AttemptRejected():
        _setItem(item.copyWith(status: OutboxStatus.failed, lastError: outcome.message, attempts: item.attempts + 1));
    }
    await _persist();
  }

  /// Permanently drops a queued item without ever sending it (e.g. the user
  /// decides the entry was a mistake). This never touches a posted record —
  /// there is nothing on the server to undo, because it was never sent.
  Future<void> discard(String id) async {
    _removeItem(id);
    await _persist();
  }

  void _setItem(OutboxItem updated) {
    state = [for (final i in state) if (i.id == updated.id) updated else i];
  }

  void _removeItem(String id) {
    state = state.where((i) => i.id != id).toList();
  }

  /// Runs the one real HTTP call for `item.kind`, with `item.id` as the
  /// Idempotency-Key so a retry (automatic or manual) after a dropped
  /// connection is replayed by the backend instead of posted twice.
  Future<_Attempt> _attempt(OutboxItem item) async {
    try {
      switch (item.kind) {
        case OutboxKind.income:
          await ref
              .read(accountingRepositoryProvider)
              .recordIncome(
                item.workspaceId,
                toAccountId: item.payload['toAccountId'] as String,
                incomeAccountId: item.payload['incomeAccountId'] as String,
                amount: item.payload['amount'] as String,
                memo: item.payload['memo'] as String?,
                contactId: item.payload['contactId'] as String?,
                animalId: item.payload['animalId'] as String?,
                landParcelId: item.payload['landParcelId'] as String?,
                idempotencyKey: item.id,
              );
          _invalidateTransactions();
        case OutboxKind.expense:
          await ref
              .read(accountingRepositoryProvider)
              .recordExpense(
                item.workspaceId,
                fromAccountId: item.payload['fromAccountId'] as String,
                expenseAccountId: item.payload['expenseAccountId'] as String,
                amount: item.payload['amount'] as String,
                memo: item.payload['memo'] as String?,
                contactId: item.payload['contactId'] as String?,
                animalId: item.payload['animalId'] as String?,
                landParcelId: item.payload['landParcelId'] as String?,
                idempotencyKey: item.id,
              );
          _invalidateTransactions();
        case OutboxKind.transfer:
          await ref
              .read(accountingRepositoryProvider)
              .recordTransfer(
                item.workspaceId,
                fromAccountId: item.payload['fromAccountId'] as String,
                toAccountId: item.payload['toAccountId'] as String,
                amount: item.payload['amount'] as String,
                memo: item.payload['memo'] as String?,
                idempotencyKey: item.id,
              );
          _invalidateTransactions();
        case OutboxKind.animalWeight:
          await ref
              .read(farmRepositoryProvider)
              .addWeight(
                item.workspaceId,
                item.animalId!,
                recordDate: DateTime.parse(item.payload['recordDate'] as String),
                weightKg: item.payload['weightKg'] as String,
                idempotencyKey: item.id,
              );
          invalidateFarmFromRef(ref, animalId: item.animalId);
        case OutboxKind.animalHealth:
          await ref
              .read(farmRepositoryProvider)
              .addHealthRecord(item.workspaceId, item.animalId!, item.payload, idempotencyKey: item.id);
          invalidateFarmFromRef(ref, animalId: item.animalId);
      }
      return const _AttemptSynced();
    } on DioException catch (error) {
      if (_isConnectivityError(error)) {
        return _AttemptOffline(_connectivityMessage(error));
      }
      return _AttemptRejected(_rejectionMessage(error));
    } catch (error) {
      // Anything not from the network layer (a bug in payload construction,
      // for instance) must not be swallowed into "queued forever" silently.
      return _AttemptRejected(error.toString());
    }
  }
}

/// A request that never reached the server (no response at all): DNS
/// failure, connection refused/reset, or a client-side timeout. Anything
/// with an actual HTTP response — even a 5xx — is treated as the server
/// having spoken, so it goes to [_AttemptRejected] instead of being retried
/// forever against a server that is deliberately saying no.
bool _isConnectivityError(DioException error) =>
    error.response == null &&
    const {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.unknown,
    }.contains(error.type);

String _connectivityMessage(DioException error) => 'Could not reach the server (${error.type.name}). Will retry automatically.';

String _rejectionMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final details = data['details'];
    if (details is List && details.isNotEmpty) return details.whereType<String>().join('\n');
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
  }
  return 'The server rejected this (${error.response?.statusCode ?? 'no response'}).';
}

sealed class _Attempt {
  const _Attempt();
}

class _AttemptSynced extends _Attempt {
  const _AttemptSynced();
}

class _AttemptOffline extends _Attempt {
  const _AttemptOffline(this.message);
  final String message;
}

class _AttemptRejected extends _Attempt {
  const _AttemptRejected(this.message);
  final String message;
}
