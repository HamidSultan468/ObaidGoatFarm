# Offline Mode & Synchronization (Phase 13)

**Status: built and verified live (2026-11-04).** Both halves exist: the server-side safety nets (idempotency keys, optimistic concurrency) and the Flutter client that actually uses them (connectivity detection, an encrypted write-outbox, automatic retry, a sync-status UI).

## Scope, deliberately

This is a **write-outbox**, not an offline read cache. Lists (transactions, animals, accounts, ...) always come from the live API; the app does not try to merge unsynced drafts into them, because that risks showing a financial total that doesn't match what the server actually holds. What the user sees instead is a pending-items badge ("this hasn't synced yet") until the item actually posts. This directly satisfies CLAUDE.md's "never silently overwrite a posted financial record" — a posted journal entry is immutable by design already (reversal-only corrections, D004/D024), and the outbox never touches edits to a posted record; it only queues *new* writes.

Covered write kinds: Record Income, Record Expense, Record Transfer, Add Weight, Add Health Record. Not covered (deliberately online-only): adding a new animal/land parcel and recording an animal's exit — these are infrequent, high-consequence creates where forcing a live round-trip is the safer default.

## Server side

- **Idempotency keys** (`backend/src/common/idempotency/`): any `POST` carrying an `Idempotency-Key` header (8–100 chars, `[A-Za-z0-9_-]`) is deduplicated. First request executes and its response (status + body) is cached against `(user, key, request-hash)` for 7 days; a retry with the same key and the same request body replays the cached response (`Idempotent-Replayed` header) instead of posting twice. A retry with the same key but a *different* body is rejected `422` — a key is a promise about one specific request, not a free pass to reuse. A failed attempt (network error, validation failure) does not burn its key, so a corrected retry still succeeds. Five simultaneous submissions with the same key post exactly one entry (DB-level uniqueness, not just an application check). Keys are scoped per user.
- **Optimistic concurrency (`If-Match`)**: `Animal.update()` and `LandParcel.update()` accept an `If-Match` header carrying the record's last-known `updatedAt`. An edit based on a stale value is refused `412 Precondition Failed` and never applied — the caller must reload and retry, so two people editing the same record can't silently clobber each other.
- Both are generic infrastructure, not report/sync-specific — any future endpoint gets idempotency by adding the header and gets conflict detection by adding `If-Match` the same way these two did.

## Client side (Flutter)

- `core/offline/connectivity_controller.dart` — `connectivityProvider` (online/offline, via `connectivity_plus`), seeded with the current state on first read, then live updates.
- `core/offline/outbox_store.dart` — `OutboxStore`/`SecureOutboxStore`: the pending-writes queue persisted through `flutter_secure_storage` (encrypted at rest, same mechanism as session tokens), survives app restarts.
- `core/offline/outbox_controller.dart` — `OutboxController`: the single place every covered write goes through.
  - `submit()` attempts the write immediately. Online and accepted → `OutboxSubmitSynced` (behaves exactly like the old direct-call path, nothing queued). Can't reach the server → `OutboxSubmitQueued`, saved to the encrypted queue. Server actively rejects it (validation, permission) → `OutboxSubmitRejected(message)`, nothing queued — that's the caller's to fix, not a retryable sync problem.
  - Every attempt — including the first, failed one — carries the *same* `Idempotency-Key` (the outbox item's own id), so an automatic retry after reconnecting replays as the same request rather than posting a duplicate.
  - `ref.listen(connectivityProvider, ...)` retries the whole pending queue automatically on the offline→online edge only (not on every "still online" tick); a manual "Retry now" / "Discard" is available per item from the sync-status sheet.
  - A synced item invalidates the relevant data providers (transactions/accounts/reports or the affected animal) so the next screen that reads them re-fetches instead of showing stale data.
- `features/shell/presentation/widgets/sync_status.dart` — top-bar indicator + a bottom sheet listing queued/failed items with retry/discard, so "this hasn't synced yet" is always visible, never silent.
- `If-Match` is wired into the two existing edit call sites that need it today: the animal health-status switch and the land parcel status switch, each catching `412` with a friendly "someone else changed this, reloading" message plus an automatic reload.

## What's intentionally not built

- A full offline *read* cache (see "Scope" above — deliberate, not a gap).
- Conflict resolution UI beyond "reload and retry" — `412` always wins to the server's current state; there is no merge view. Acceptable because the only conflict surfaces today (animal/land status) are a single enum field, not a multi-field form.
- Background sync while the app is closed — retry triggers only on the connectivity transition while the app is running, or a manual tap. A platform background-fetch integration is future scope if needed.

## Verification (2026-11-04)

- Backend: idempotency (8 checks) and `If-Match` (3 checks) are part of the 37/37 live E2E suite below reports — see [TESTING_QA.md](TESTING_QA.md).
- Flutter: `app/test/outbox_controller_test.dart` — 9/9 tests (synced/queued/rejected outcomes, automatic retry on reconnect reusing the same key, discard, manual retry, 5 queued items replayed in creation order). `app/test/record_transaction_dialog_test.dart` and `app/test/farm_dialogs_test.dart` updated to route through the outbox.
- A real race was found and fixed while writing the controller test: `addTearDown` runs in **LIFO** order, so a `StreamController.close()` registered *before* the `ProviderContainer.dispose()` that cancels Riverpod's subscription to it hangs forever waiting for a listener only `dispose()` would remove. Fixed by registering `dispose()` first. Documented here as a reusable gotcha for any future test combining a `ProviderContainer` and a manually-controlled stream.
- A second finding: a plain (non-autoDispose) `StreamProvider` only actually subscribes to its underlying stream while something is watching/listening to it. In the running app that's always true (the top-bar sync indicator watches `connectivityProvider`); a bare `ProviderContainer` test has no such widget, so it needs its own no-op `container.listen(connectivityProvider, ...)` to keep the provider live — otherwise it sits in `AsyncLoading` forever and the controller's own retry-on-reconnect listener never fires.
