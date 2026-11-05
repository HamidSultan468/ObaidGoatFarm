# Data Model

Source of truth: [backend/prisma/schema.prisma](backend/prisma/schema.prisma). This document explains the *why* behind the schema; the schema file itself is authoritative for field-level detail.

## Scope of this document

Covers Phase 02/03 (tenancy, identity/access, audit) and Phase 05 (the full Financial Management Core schema — see [ACCOUNTING.md](ACCOUNTING.md) for the module overview). One intentionally minimal stub remains: **Animal**, which exists solely so the Phase 04 dashboard's "Total Goats" widget shows real data instead of mock numbers. The full Phase 06 (goat farm) and Phase 07 (land) schemas will extend, not replace, that stub when those phases are built.

## Tenancy

**Workspace** is the tenant boundary. Every tenant-scoped table carries a `workspaceId` foreign key to it. This is the mechanism behind the multi-tenant isolation requirement in CLAUDE.md §4 — see DECISIONS.md D005 for the enforcement strategy (query-layer + guard, defense in depth). `Workspace.approvalThreshold` is the Phase 05 approval-routing control — see DECISIONS.md D016.

## Identity & Access

- **User** is a platform-level account (one row per human, regardless of how many workspaces they belong to). Carries a `globalRole` (`SUPER_ADMIN_OWNER` / `ADMIN` / `USER`) used only for the Super Admin control panel, and `preferredLanguage` (`en`/`ur`) for the CLAUDE.md §1 localization requirement.
- **WorkspaceMembership** is the many-to-many join between `User` and `Workspace`, carrying the per-tenant `WorkspaceRole` (`OWNER`/`ADMIN`/`MANAGER`/`STAFF`/`VIEWER`). This is the row `WorkspaceGuard` checks on every tenant-scoped request.
- **RefreshToken** stores only a SHA-256 hash of each refresh token, never the raw value. Rotated (revoked + reissued) on every use. `deviceId` (opaque, client-generated) is the join key into **UserDevice** below.
- **UserDevice** — `deviceId` + `@@unique([userId, deviceId])` (added 2026-11-05) links it to the matching `RefreshToken.deviceId`; `deviceName`/`platform` are reported by the client at login and shown in "Active sessions" (DECISIONS.md D045, supersedes D013's "not yet surfaced" note). Upserted only when the client sends all three device headers — a session from before this existed, or a minimal client, just shows the bare `deviceId`.

## Audit

**AuditLog** is append-only (no update/delete path is ever exposed). `workspaceId` and `userId` are nullable because some actions (e.g. a failed login, a Super Admin global action) aren't scoped to a single workspace or an authenticated user.

## Financial Management Core (Phase 05)

### The ledger
- **Account** — the chart of accounts. `type` (`ASSET`/`LIABILITY`/`EQUITY`/`INCOME`/`EXPENSE`) is the accounting classification; `kind` (`CASH`/`BANK`/`RECEIVABLE`/`PAYABLE`/`GENERAL`) is a finer sub-classification used to pick which accounts count as "liquid" for the dashboard's Bank Balance KPI and the cash-flow report. `isSystemAccount` marks the accounts auto-seeded on workspace creation (DECISIONS.md D015) — they can be deactivated but never deleted.
- **JournalEntry** — a balanced group of lines. `status` (`POSTED`/`PENDING_APPROVAL`/`REJECTED`) implements the approval workflow (DECISIONS.md D016); only `POSTED` entries count in any balance, statement, or report. `entryType` records which guided flow created it (`INCOME`/`EXPENSE`/`TRANSFER`/`MANUAL`/... ). `verificationCode` backs the QR-receipt feature (DECISIONS.md D019) when set. `reversalOfId` is the only correction path for a posted entry — never an update or delete (CLAUDE.md §3).
- **JournalLine** — positive amount = debit, negative = credit (DECISIONS.md D004 — always `Decimal`, never float). `reconciledAt` is bank-reconciliation matching — set/cleared via `PATCH .../lines/:lineId/reconcile`, surfaced as a checklist in the Flutter Account Statement sheet (2026-11-05).
- A `JournalEntry` is valid only when its lines' signed amounts sum to exactly zero — enforced in code (`assertBalanced`), not just by convention.

### Customers & suppliers
**Contact** (`CUSTOMER`/`SUPPLIER`/`BOTH`) has no parallel bookkeeping — a contact's ledger is simply the set of `JournalEntry` rows with that `contactId` (entry-level attribution only, not per-line — see DECISIONS.md D015 area / ACCOUNTING.md "Known simplifications").

### Recurring & budgets
- **RecurringTemplate** — a reusable transaction definition with a `frequency` and `nextRunDate`. Posting is manual (`run-now`), never automatic yet — see DECISIONS.md D017.
- **Budget** — a planned `amount` for one `Account` over `[periodStart, periodEnd]`, compared against actual posted activity on request (not pre-computed/cached).

## Goat Farm (Phase 06)

- **Animal** — `tagNumber` unique per workspace; `sex`; `status` (ACTIVE/SOLD/DECEASED, one-way) kept separate from `healthStatus` (HEALTHY/SICK/UNDER_TREATMENT/QUARANTINED); `acquisition`; optional `sireId`/`damId` self-relations (pedigree; SetNull on delete); `exitDate`/`exitReason`.
- **AnimalHealthRecord** — typed record (VACCINATION, DEWORMING, …) with medicine/dosage/vet and `nextDueDate`, which drives the farm schedule.
- **AnimalWeightRecord** — `weightKg` as `numeric(8,3)` (never float).
- **BreedingRecord** — dam, farm sire or `externalSire`, method, `matingDate`, `expectedKiddingDate`, `status` (MATED → PREGNANT/NOT_PREGNANT/ABORTED, or KIDDED via the kidding endpoint), kids born/alive, complications.

## Land (Phase 07)

- **LandParcel** — name, location, `surveyNumber` (khasra), `tenure`, `status`, `areaValue` + `areaUnit` as entered, and `areaSqFt` (`numeric(18,4)`) as the canonical value; optional lease counterparty (`Contact`), lease dates and terms.

## Documents (Phase 08)

- **Attachment** — `module` (ANIMAL/LAND/TRANSACTION/CONTACT/GENERAL) + `recordId`, title, sanitized `fileName`, sniffed `mimeType`, `sizeBytes`, plaintext `sha256`, and a server-only `storageKey` pointing at the encrypted file.

## Tags on journal entries

`JournalEntry.animalId` and `JournalEntry.landParcelId` (both optional, SetNull on delete, indexed) let per-animal and per-parcel profitability be computed from the one ledger — there is no parallel bookkeeping in the farm or land modules.

## Notifications (Phase 09)

- **Notification** — one row per recipient (`userId`), optional `workspaceId` (null = platform announcement), `category`, `severity`, `link`, `readAt`; unique `(userId, dedupeKey)` so rule reminders are created once.
- **NotificationDelivery** — one EMAIL delivery per notification when the user chose email: `status` (PENDING/SENT/FAILED/SKIPPED), `attempts`, `lastError`, `nextAttemptAt`.
- **NotificationPreference** — per user and category: `inApp`, `email`. **User** gains `timeZone`, `quietHoursStart/End`.
- **WorkspaceNotificationRule** — per workspace and category: `isEnabled`, `recipientRoles[]`.

## Backup (Phase 10)

- **Backup** — `trigger` (MANUAL/SCHEDULED), `status`, provider, server-only `storageKey`, `sizeBytes`, `sha256` of the encrypted file, `formatVersion`, `counts`, `error`. **Workspace** gains `autoBackupEnabled`, `backupRetention`.

## AI, drafts and WhatsApp (Phase 11)

- **AiProviderConfig** — `provider` (ANTHROPIC), `model`, `apiKeyEncrypted`, `keyHint`, `priority`, `isEnabled`, `monthlyRequestLimit`. **AiUsageLog** — one row per provider call (feature, success, tokens, latency, error).
- **RecordDraft** — `source` (AI_TEXT/AI_RECEIPT/WHATSAPP), `kind` (INCOME/EXPENSE/ANIMAL_HEALTH/ANIMAL_WEIGHT), `status` (PENDING/APPROVED/REJECTED), `payload` (proposed fields), `warnings`, `rawInput`, reviewer, `resultType`/`resultId` of the record approval created.
- **WhatsAppConfig** — per workspace: `phoneNumberId` (unique), encrypted token and app secret, `verifyToken`. **WhatsAppLink** — member ↔ phone (E.164), `verifiedAt`, hashed one-time code, `failedAttempts`. **WhatsAppMessageLog** — inbound/outbound, unique `waMessageId` (webhook retries processed once), status, error, `draftId`.

## Reporting (Phase 12)

No new tables — every analytics report (financial summary, balance sheet, trial balance, farm performance, animal growth, land, audit log, operations) is computed on demand from existing data (`JournalLine`, `Animal`, `LandParcel`, `AuditLog`, ...) via `backend/src/modules/analytics/`. Nothing is cached or duplicated into a reporting-specific table.

## Offline & idempotency (Phase 13)

- **IdempotencyRecord** — `(userId, key)` unique, `requestHash` (SHA-256 of method + path + body, so a reused key with a different body is rejected), `statusCode`/`responseBody` (null while the first request is still in flight), auto-purged after 7 days by a daily cron. See DECISIONS.md D037.
- No schema change for optimistic concurrency (D038) — `Animal`/`LandParcel` already carry Prisma's standard `updatedAt`, which the `If-Match` header is checked against.
- No schema change on the Flutter side either — the write-outbox queue lives entirely in encrypted local storage (`flutter_secure_storage`), never synced to the server as its own record.

## Money representation

Every monetary field is Prisma `Decimal` → PostgreSQL `numeric(18,4)`. See DECISIONS.md D004. Application code must go through `backend/src/common/money/money.ts` rather than operating on `Decimal`/`number` directly, so rounding and arithmetic rules stay centralized. The same discipline now extends through the whole accounting module — every service that touches an amount does so via `Money`, never a parsed `number`.
