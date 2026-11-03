# Data Model

Source of truth: [backend/prisma/schema.prisma](backend/prisma/schema.prisma). This document explains the *why* behind the schema; the schema file itself is authoritative for field-level detail.

## Scope of this document

Covers the Phase 02/03 foundation schema only: tenancy, identity/access, audit, and two intentionally minimal stubs (ledger, animal) that exist solely so the Phase 04 dashboard can show real data instead of mock numbers. Full Phase 05 (accounting), 06 (goat farm), 07 (land) schemas will be added — and will extend, not replace, these stubs — when those phases are built.

## Tenancy

**Workspace** is the tenant boundary. Every tenant-scoped table carries a `workspaceId` foreign key to it. This is the mechanism behind the multi-tenant isolation requirement in CLAUDE.md §4 — see DECISIONS.md D005 for the enforcement strategy (query-layer + guard, defense in depth).

## Identity & Access

- **User** is a platform-level account (one row per human, regardless of how many workspaces they belong to). Carries a `globalRole` (`SUPER_ADMIN_OWNER` / `ADMIN` / `USER`) used only for the Super Admin control panel, and `preferredLanguage` (`en`/`ur`) for the CLAUDE.md §1 localization requirement.
- **WorkspaceMembership** is the many-to-many join between `User` and `Workspace`, carrying the per-tenant `WorkspaceRole` (`OWNER`/`ADMIN`/`MANAGER`/`STAFF`/`VIEWER`). This is the row `WorkspaceGuard` checks on every tenant-scoped request.
- **RefreshToken** stores only a SHA-256 hash of each refresh token, never the raw value. Rotated (revoked + reissued) on every use.
- **UserDevice** supports the Phase 03 device-management requirement; not yet surfaced in any UI.

## Audit

**AuditLog** is append-only (no update/delete path is ever exposed). `workspaceId` and `userId` are nullable because some actions (e.g. a failed login, a Super Admin global action) aren't scoped to a single workspace or an authenticated user.

## Ledger stub (full engine is Phase 05)

**Account** / **JournalEntry** / **JournalLine** implement the minimum shape of a double-entry ledger: a `JournalEntry` is valid only when its `JournalLine.amount` values (signed: positive = debit, negative = credit) sum to exactly zero. `reversalOfId` on `JournalEntry` is the only way to correct a posted entry — there is no update/delete path for a posted entry, per CLAUDE.md §3.

This stub intentionally does **not** yet include: recurring transactions, budgets, approval workflows, multi-currency, or reconciliation — those belong to the full Phase 05 build-out.

## Animal stub (full module is Phase 06)

**Animal** currently has only an id, tag number, and health status — enough for the dashboard's "Total Goats" widget to query a real count. Breed, pedigree, health records, breeding/kidding records, etc. are Phase 06 scope.

## Money representation

Every monetary field is Prisma `Decimal` → PostgreSQL `numeric(18,4)`. See DECISIONS.md D004. Application code must go through `backend/src/common/money/money.ts` rather than operating on `Decimal`/`number` directly, so rounding and arithmetic rules stay centralized.
