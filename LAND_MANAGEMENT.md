# Land Management (Phase 07)

**Status: core built and verified live (2026-11-04).**

## What exists

- **Parcels** (`backend/src/modules/land/`): name, location, khasra/survey number, owner, land use, tenure (owned / leased in / leased out / rented out), status (active / lease ended / sold), lease counterparty (a workspace Contact), lease dates and terms.
- **Area**: entered in kanal, marla, acre, sq ft, sq m or hectare; stored canonically as `areaSqFt` (Decimal) next to the original value and unit. Every response includes all conversions and an "acre kanal marla" breakdown (`area.util.ts`, unit-tested). Marla = 272.25 sq ft, the revenue standard (DECISIONS.md D023 — owner to confirm). `GET /land/convert` is a standalone calculator.
- **Profitability**: crop sales, rent, labor, irrigation, fertilizer and maintenance are ordinary income/expense entries tagged with `landParcelId`. Each parcel shows income/expense/net; `GET /land/reports/profitability` lists every parcel plus a total, with an optional date range.
- **Flutter**: `app/lib/features/land/` (Land Records list, parcel detail, Add land dialog); photos and documents attach via the Documents module.

## Not yet built

- Maps / boundaries.
- Purchase, sale, lease and rental templates ([TEMPLATES.md](TEMPLATES.md)).
- Editing a parcel from the UI (API supports it; the UI changes status only).
- A per-workspace marla-size setting (data model already supports recomputing).
- Urdu strings for the Land screens.
