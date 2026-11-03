# Land Management (Phase 07)

**Status: not started.** Nothing in the schema, backend, or Flutter app exists for this module yet — not even a stub. This document records planned scope so Phase 07 has a clear starting brief.

## Planned scope (from CLAUDE.md §Phase 07)

- Individual land and property records
- Ownership, location, measurements, and area conversions (e.g. kanal/marla/acre conversions common in this context — exact unit set to be confirmed when this phase starts)
- Templates for land purchase, sale, lease, and rental (see [TEMPLATES.md](TEMPLATES.md))
- Agricultural income and land-related expense tracking
- Labor, irrigation, fertilizer, maintenance, and other cost records
- Separate land accounts and profitability reports per property
- Photographs, maps, and document attachments

## Notes for when this phase starts

- Like [ACCOUNTING.md](ACCOUNTING.md) and [GOAT_FARM.md](GOAT_FARM.md), land income/expense should post against the real double-entry ledger (Phase 05), not maintain a parallel bookkeeping system.
- "Separate land accounts" suggests each property may need its own `Account` (or a sub-ledger keyed by a `landId`) — a schema decision to make when this phase is actually designed, not guessed at here.
