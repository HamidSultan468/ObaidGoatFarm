# Offline Mode & Synchronization (Phase 13)

**Status: not started.** The current Flutter app requires a live connection to the backend for every action (no local persistence layer exists).

## Planned scope (from CLAUDE.md §Phase 13)

- Encrypted offline drafts
- Secure synchronization with the central backend
- Duplicate-submission and conflicting-update detection
- Clear synchronization status in the UI
- Never silently overwrite a posted financial record
- Data integrity verification after sync

## Notes for when this phase starts

- This is one of the stronger reasons Flutter was chosen (DECISIONS.md D001) — needs a local database (likely `drift` or `isar`, to be decided when this phase starts) mirroring the subset of backend data relevant to offline use.
- "Never silently overwrite a posted financial record" directly reinforces the immutability rule already built into the ledger schema (`JournalEntry` + `reversalOfId`) — a sync conflict on a posted entry should always require explicit resolution, never an automatic merge.
- Conflict detection likely needs a version/revision counter or timestamp-based optimistic concurrency on syncable records — not yet designed into the current schema, since nothing is offline-capable yet.
