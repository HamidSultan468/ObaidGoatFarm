# API Contracts

Base URL (dev): `http://localhost:3000`. All request/response bodies are JSON. Authenticated requests send `Authorization: Bearer <accessToken>`.

Error responses always have the shape:
```json
{ "statusCode": 400, "code": "BadRequestException", "message": "...", "correlationId": "uuid", "details": ["optional per-field validation errors"] }
```

## Auth (`/auth`) — implemented

All endpoints below are public (no bearer token required) except `GET /auth/me`.

### `GET /auth/me`
Requires `Authorization: Bearer <accessToken>`. Returns the caller's current profile (lets a client restore its session on app start without re-prompting for credentials):
```json
{ "id": "uuid", "email": "...", "fullName": "...", "globalRole": "USER", "preferredLanguage": "en", "mfaEnabled": false }
```
`401` if the access token is missing/expired/invalid.

### `POST /auth/register`
Request:
```json
{ "email": "owner@example.com", "password": "at-least-12-chars", "fullName": "Obaid Khan", "preferredLanguage": "en" }
```
Response `201`:
```json
{ "id": "uuid", "email": "owner@example.com", "fullName": "Obaid Khan", "globalRole": "USER", "preferredLanguage": "en", "mfaEnabled": false }
```
`409` if the email is already registered.

### `POST /auth/login`
Request:
```json
{ "email": "owner@example.com", "password": "..." }
```
Optional header: `X-Device-Id: <client-generated-device-id>` — associates the issued refresh token with a session for later session management (`/auth/sessions`).

Response `200` — if the account does **not** have MFA enabled:
```json
{
  "accessToken": "jwt",
  "refreshToken": "opaque-hex-string",
  "profile": { "id": "uuid", "email": "...", "fullName": "...", "globalRole": "USER", "preferredLanguage": "en", "mfaEnabled": false }
}
```
Response `200` — if the account **has** MFA enabled, no tokens are issued yet:
```json
{ "mfaRequired": true, "mfaToken": "short-lived-jwt" }
```
Continue with `POST /auth/mfa/login` (DECISIONS.md D012). `401` on invalid credentials or inactive account.

### `POST /auth/mfa/login`
Public. Second step of login for an MFA-enabled account. Request:
```json
{ "mfaToken": "short-lived-jwt-from-login-response", "code": "123456" }
```
Response `200`: same shape as a normal successful login (`accessToken`, `refreshToken`, `profile`). `401` if the challenge token is expired/invalid or the code is wrong.

### `POST /auth/refresh`
Request:
```json
{ "refreshToken": "opaque-hex-string" }
```
Response `200`: new `{ accessToken, refreshToken }` pair. The submitted refresh token is revoked on use (rotation) — reusing it will `401`.

### `POST /auth/logout`
Request:
```json
{ "refreshToken": "opaque-hex-string" }
```
Response `204`. Revokes the given refresh token.

### MFA management (`/auth/mfa/*`) — requires `Authorization: Bearer <accessToken>`

- **`POST /auth/mfa/setup`** — generates and stores (encrypted) a new TOTP secret; does not enable MFA yet. Response `201`: `{ "secret": "base32...", "otpauthUrl": "otpauth://totp/..." }` — render `otpauthUrl` as a QR code and/or show `secret` for manual entry.
- **`POST /auth/mfa/verify-setup`** — body `{ "code": "123456" }`. Verifies the code against the pending secret and, if valid, enables MFA. Response `204`. `401` on a wrong code, `400` if setup wasn't started.
- **`POST /auth/mfa/disable`** — body `{ "code": "123456" }`. Requires a currently-valid code (not just an active session) to turn MFA off. Response `204`. `401` on a wrong code, `400` if MFA isn't enabled.

### Sessions (`/auth/sessions`) — requires `Authorization: Bearer <accessToken>`

A "session" is an active (non-revoked, unexpired) refresh token (DECISIONS.md D013) — this is the basis for device/session management today.

- **`GET /auth/sessions`** — Response `200`: `[{ "id": "uuid", "deviceId": "string|null", "createdAt": "ISO", "expiresAt": "ISO" }]`.
- **`DELETE /auth/sessions/:sessionId`** — revokes that session (effectively logs it out next time it tries to refresh). Response `204`. `404` if it doesn't belong to the caller.

## Workspaces (`/workspaces`) — implemented

All endpoints below require `Authorization: Bearer <accessToken>`.

### `POST /workspaces`
Creates a workspace; the caller becomes its `OWNER`. Request:
```json
{ "name": "Obaid Goat Farm", "slug": "obaid-goat-farm" }
```
`slug` is optional — auto-generated from `name` (lowercased, hyphenated, de-duplicated) when omitted. Response `201`: the created `Workspace`.

### `GET /workspaces`
Lists workspaces the caller is an active member of. Response `200`: `Workspace[]`.

### `GET /workspaces/:workspaceId`
Requires active membership in that workspace (`WorkspaceGuard`). Response `200`: the `Workspace`. `403` if the caller isn't a member, `404` if it doesn't exist or is inactive.

### `POST /workspaces/:workspaceId/members`
Requires the caller to hold `OWNER` or `ADMIN` in that workspace. Request:
```json
{ "email": "staff@example.com", "role": "STAFF" }
```
`role` must be one of `ADMIN`/`MANAGER`/`STAFF`/`VIEWER` (not `OWNER` — ownership isn't granted via a plain invite). Response `201`: the created `WorkspaceMembership`. `404` if no account exists yet for that email (they must register first — there is no pending-invite-for-unregistered-user flow yet). `409` if already a member.

## Accounting (Phase 05) — implemented

All endpoints below require `Authorization: Bearer <accessToken>` and active membership in `:workspaceId` (`WorkspaceGuard`), except `GET /receipts/verify/:code`, which is public. See [ACCOUNTING.md](ACCOUNTING.md) for the module overview and known simplifications.

### Accounts — `/workspaces/:workspaceId/accounts`
- **`POST /`** — OWNER/ADMIN only. Body: `{ "code": "1050", "name": "Petty Cash", "type": "ASSET", "kind": "CASH" }` (`kind` optional, defaults `GENERAL`). `409` on duplicate code.
- **`GET /`** — list all accounts.
- **`GET /:accountId`** — one account.
- **`GET /:accountId/balance`** — `{ "accountId", "balance": "1234.5600" }`, summed from POSTED lines only.
- **`GET /:accountId/statement?from=&to=`** — `{ "accountId", "rows": [{ "journalEntryId", "postedAt", "memo", "documentNumber", "amount", "runningBalance" }], "closingBalance" }`.
- **`PATCH /:accountId/status`** — OWNER/ADMIN only. Body `{ "isActive": false }`. `400` if the account is a system account.

### Contacts (customers/suppliers) — `/workspaces/:workspaceId/contacts`
- **`POST /`** — Body: `{ "type": "CUSTOMER" | "SUPPLIER" | "BOTH", "name", "email"?, "phone"?, "address"?, "notes"? }`.
- **`GET /`** — list all contacts.
- **`GET /:contactId`** — one contact.
- **`GET /:contactId/ledger`** — `{ "entries": [JournalEntry...], "totalNet": "..." }` — every POSTED entry tagged to this contact.
- **`PATCH /:contactId`** — partial update, same fields as create.
- **`PATCH /:contactId/status`** — Body `{ "isActive": false }`.

### Transactions — `/workspaces/:workspaceId/transactions`
- **`POST /income`** — Body: `{ "toAccountId", "incomeAccountId", "amount": "1250.00", "memo"?, "contactId"?, "documentNumber"?, "issueReceipt"? }`. Returns the created `JournalEntry` (with `verificationCode` set if `issueReceipt: true`).
- **`POST /expense`** — Body: `{ "fromAccountId", "expenseAccountId", "amount", "memo"?, "contactId"?, "documentNumber"? }`.
- **`POST /transfer`** — Body: `{ "fromAccountId", "toAccountId", "amount", "memo"? }`.
- **`POST /manual`** — Body: `{ "lines": [{ "accountId", "amount": "100.00" }, { "accountId", "amount": "-100.00" }], "memo"?, "documentNumber"?, "contactId"? }` — `amount` positive = debit, negative = credit; lines must balance to zero or `400`.
- **`GET /?limit=50`** — recent entries, newest first, with lines and contact included.
- **`GET /pending-approvals`** — OWNER/ADMIN only. Entries awaiting approval.
- **`GET /:entryId`** — one entry.
- **`POST /:entryId/reverse`** — OWNER/ADMIN only. Creates and returns a reversing entry. `400` if already reversed or not POSTED.
- **`POST /:entryId/approve`** / **`POST /:entryId/reject`** — OWNER/ADMIN only, on a `PENDING_APPROVAL` entry.

Every POST above returns `201` with the `JournalEntry` (including its `lines`).

### Reports — `/workspaces/:workspaceId/reports`
- **`GET /trial-balance`** — `{ "rows": [{ "accountId", "code", "name", "type", "debit", "credit" }], "totalDebit", "totalCredit", "isBalanced" }`.
- **`GET /profit-and-loss?from=&to=`** — defaults to the current calendar month. `{ "income": [...], "expenses": [...], "totalIncome", "totalExpense", "netProfit" }`.
- **`GET /cash-flow?from=&to=`** — `{ "totalInflows", "totalOutflows", "netChange" }` (simplified — see ACCOUNTING.md).
- **`GET /liquid-balance`** — `{ "balance": "..." }`, sum of all CASH/BANK account balances.

### Budgets — `/workspaces/:workspaceId/budgets`
- **`POST /`** — OWNER/ADMIN/MANAGER only. Body: `{ "accountId", "periodStart": "ISO date", "periodEnd": "ISO date", "amount" }`.
- **`GET /`** — list all budgets.
- **`GET /:budgetId/progress`** — `{ "budget", "actual", "remaining", "percentUsed" }`.

### Recurring templates — `/workspaces/:workspaceId/recurring-templates`
- **`POST /`** — OWNER/ADMIN/MANAGER only. Body: `{ "name", "entryType", "fromAccountId", "toAccountId", "contactId"?, "amount", "memo"?, "frequency": "DAILY"|"WEEKLY"|"MONTHLY"|"YEARLY", "nextRunDate" }`.
- **`GET /`** — list all templates.
- **`PATCH /:templateId/status`** — Body `{ "isActive": false }`.
- **`POST /:templateId/run-now`** — OWNER/ADMIN/MANAGER only. Posts a journal entry from the template and advances `nextRunDate`. There is no automatic/scheduled execution — see ACCOUNTING.md D017.

### Receipts — `/receipts` (public, no `:workspaceId`)
- **`GET /verify/:code`** — Public. `{ "valid": true, "documentNumber", "memo", "amount", "postedAt", "workspaceName" }`. `404` if the code doesn't match a POSTED, receipt-issuing entry.

## Admin Console (`/admin`) — implemented

All endpoints require `Authorization: Bearer <accessToken>` from a caller whose platform `GlobalRole` is `SUPER_ADMIN_OWNER` or `ADMIN` (read) — mutations additionally require `SUPER_ADMIN_OWNER` **and** MFA enabled on the caller's account (`MfaRequiredGuard` — CLAUDE.md §3's "protect critical owner operations with MFA", see SECURITY.md).

- **`GET /admin/workspaces`** — every workspace platform-wide, with member counts. Response `200`: `[{ "id", "name", "slug", "isActive", "_count": { "users": 3 } }]`.
- **`PATCH /admin/workspaces/:workspaceId/status`** — body `{ "isActive": false }`. Owner+MFA only. `404` if not found.
- **`GET /admin/users`** — every user platform-wide (never includes `passwordHash`/`mfaSecretEncrypted`). Response `200`: `[{ "id", "email", "fullName", "globalRole", "isActive", "mfaEnabled", "preferredLanguage", "lastLoginAt", "createdAt" }]`.
- **`PATCH /admin/users/:userId/status`** — body `{ "isActive": false }`. Owner+MFA only. `400` if targeting your own account's deactivation; `403` if targeting the Super Admin Owner account.
- **`PATCH /admin/users/:userId/global-role`** — body `{ "globalRole": "ADMIN" | "USER" }`. Owner+MFA only. `400` if targeting yourself; `403` if targeting the Super Admin Owner account (ownership isn't reassignable here).

## Health (`/health`) — implemented

### `GET /health`
Public. Response `200` if the database is reachable:
```json
{ "status": "ok", "database": "connected", "timestamp": "2026-11-03T..." }
```
`503` if the database is unreachable.

## Goat Farm (Phase 06) — implemented

All under `/workspaces/:workspaceId`, `WorkspaceGuard`. Reads: any member. Writes: OWNER/ADMIN/MANAGER/STAFF. Exit and health-record delete: OWNER/ADMIN/MANAGER. Dates are `yyyy-MM-dd`; weights are decimal strings.

| Method | Path | Notes |
|---|---|---|
| POST | `/animals` | `tagNumber`, `sex` required. `409` duplicate tag; `400` bad sire/dam |
| GET | `/animals?status=ACTIVE\|SOLD\|DECEASED\|ALL&search=` | default ACTIVE; includes latest weight |
| GET | `/animals/:id` | + sire, dam, `offspring[]`, latest weight |
| PATCH | `/animals/:id` | any profile field; never its own parent |
| POST | `/animals/:id/exit` | `{status: SOLD\|DECEASED, exitDate, exitReason?}`; one-way |
| GET/POST | `/animals/:id/health-records` | `nextDueDate ≥ recordDate` |
| DELETE | `/animals/:id/health-records/:recordId` | |
| GET/POST | `/animals/:id/weights` | `weightKg` e.g. `"32.500"`; `> 0` |
| GET | `/animals/:id/ledger` | tagged POSTED entries + `income`/`expense`/`net` |
| POST | `/breeding` | `damId`, `matingDate`; `expectedKiddingDate` defaults to +150 days; `409` if the dam has an open record |
| GET | `/breeding?open=true` | |
| PATCH | `/breeding/:id/status` | `PREGNANT\|NOT_PREGNANT\|ABORTED` (allowed transitions only) |
| POST | `/breeding/:id/kidding` | `{kiddingDate, kidsBorn, kids:[{tagNumber, sex, name?}], complications?}` → `{breedingRecord, kids}` |
| GET | `/farm/overview` | counts, `dueHealth[]` (30 days, `overdue`), `upcomingKiddings[]` |

## Land (Phase 07) — implemented

| Method | Path | Notes |
|---|---|---|
| POST | `/land` | `name`, `areaValue` (decimal string), `areaUnit` (SQUARE_FOOT/SQUARE_METER/MARLA/KANAL/ACRE/HECTARE) |
| GET | `/land?status=ACTIVE\|SOLD\|LEASE_ENDED\|ALL` | each parcel includes `areaConversions` and `areaBreakdown` |
| GET | `/land/convert?value=&unit=` | calculator, no data access |
| GET | `/land/reports/profitability?from=&to=` | `rows[]` per parcel + `total` |
| GET | `/land/:id` | + counterparty |
| PATCH | `/land/:id` | `areaValue` and `areaUnit` must be sent together |
| GET | `/land/:id/ledger` | tagged POSTED entries + `income`/`expense`/`net` |

Transactions: `POST /transactions/income|expense|manual` accept optional `animalId` and `landParcelId` (workspace-checked).

## Documents (Phase 08) — implemented

| Method | Path | Notes |
|---|---|---|
| POST | `/attachments` | multipart: `file` + `module` (+ `recordId` unless GENERAL, `title?`). JPEG/PNG/WEBP/PDF by content, ≤ 10 MB (`413`). Upload: OWNER/ADMIN/MANAGER/STAFF |
| GET | `/attachments?module=&recordId=&search=` | metadata only (never the storage key) |
| GET | `/attachments/:id/download?inline=true` | decrypted, integrity-checked bytes |
| DELETE | `/attachments/:id` | OWNER/ADMIN/MANAGER |

## Errors

Every error body is `{ statusCode, code, message, correlationId, details? }`. `details` lists field-level problems (validation errors, an incomplete draft, failed backup checks).

## Notifications (Phase 09) — implemented

| Method | Path | Who | Notes |
|---|---|---|---|
| GET | `/notifications?unread=true&workspaceId=&limit=` | self | the user's own inbox (+ platform announcements) |
| GET | `/notifications/unread-count?workspaceId=` | self | `{count}` |
| POST | `/notifications/:id/read` · `/notifications/read-all?workspaceId=` | self | |
| GET / PUT | `/notifications/preferences` | self | per-category `inApp`/`email`, `timeZone`, `quietHoursStart/End` (minutes after midnight, both or neither) |
| GET / PUT | `/workspaces/:id/notification-rules` | OWNER/ADMIN | `{rules: [{category, isEnabled, recipientRoles}]}` |
| POST | `/workspaces/:id/notification-rules/run` | OWNER/ADMIN | evaluate now → `{created, deliveries}` |
| POST | `/workspaces/:id/notifications/send` | OWNER/ADMIN | `{title, body, severity?, roles?, userIds?}` (members only) |
| GET | `/workspaces/:id/notifications/deliveries` | OWNER/ADMIN | email delivery log |
| POST | `/admin/notifications/send` | SUPER_ADMIN_OWNER + MFA | platform announcement (`userIds` optional) |

## Backup (Phase 10) — implemented

| Method | Path | Who | Notes |
|---|---|---|---|
| GET | `/workspaces/:id/backups` · `/backups/status` | OWNER/ADMIN | list / last backup, counts, bytes |
| POST | `/workspaces/:id/backups` | OWNER/ADMIN | manual backup → COMPLETED (or 500 + FAILED row + notification) |
| PATCH | `/workspaces/:id/backups/settings` | OWNER/ADMIN | `{autoBackupEnabled?, retention? (1-90)}` |
| POST | `/workspaces/:id/backups/:backupId/verify` | OWNER/ADMIN | `{valid, errors, counts, checksumMatches}` |
| GET | `/workspaces/:id/backups/:backupId/download` | OWNER/ADMIN | encrypted `.tsmbak` |
| POST | `/workspaces/:id/backups/:backupId/restore` | OWNER | verified restore into a NEW workspace → `{workspace, counts}` |
| DELETE | `/workspaces/:id/backups/:backupId` | OWNER | |
| POST | `/backups/restore-file` | owner of the source workspace / SUPER_ADMIN_OWNER | multipart `file` (≤ 200 MB) |
| POST | `/admin/backups/run-scheduled` | SUPER_ADMIN_OWNER + MFA | run the daily job now |

## AI & drafts (Phase 11) — implemented

| Method | Path | Who | Notes |
|---|---|---|---|
| GET / POST | `/workspaces/:id/ai/providers` | OWNER/ADMIN | `{apiKey, model (claude-*), priority?, monthlyRequestLimit?}`; key never returned (`keyHint` only) |
| PATCH / DELETE | `/workspaces/:id/ai/providers/:configId` | OWNER/ADMIN | |
| POST | `/workspaces/:id/ai/providers/:configId/test` | OWNER/ADMIN | `{ok, message}` |
| GET | `/workspaces/:id/ai/providers/usage` | OWNER/ADMIN | this month per provider |
| POST | `/workspaces/:id/drafts/from-text` | OWNER/ADMIN/MANAGER/STAFF | `{text}` → PENDING draft (400 not set up / 502 all providers failed) |
| POST | `/workspaces/:id/drafts/from-receipt` | same | `{attachmentId, note?}` (image or PDF) |
| GET | `/workspaces/:id/drafts?status=` · `/drafts/:draftId` | same | |
| POST | `/workspaces/:id/drafts/:draftId/approve` | same | `{payload?}` (reviewer's corrections) → `{draft, result}`; 409 if already reviewed |
| POST | `/workspaces/:id/drafts/:draftId/reject` | same | `{reason?}` |

## WhatsApp (Phase 11) — implemented

| Method | Path | Who | Notes |
|---|---|---|---|
| GET / PUT / DELETE | `/workspaces/:id/whatsapp/config` | OWNER/ADMIN | `{phoneNumberId, displayPhone?, accessToken, appSecret, isEnabled?}`; secrets never returned |
| GET / DELETE | `/workspaces/:id/whatsapp/links` · `/links/:linkId` | OWNER/ADMIN | linked members |
| GET | `/workspaces/:id/whatsapp/messages` | OWNER/ADMIN | inbound/outbound log |
| GET / POST / DELETE | `/workspaces/:id/whatsapp/my-link` | OWNER/ADMIN/MANAGER/STAFF | `POST {phone}` → `{code, instructions}` |
| GET | `/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=&hub.challenge=` | public | echoes the challenge for a known token |
| POST | `/whatsapp/webhook` | public, HMAC-signed | 401 without a valid `X-Hub-Signature-256` |

## Reporting & Analytics (Phase 12) — implemented

All require `Authorization` + workspace membership; `REPORT_ACCESS` per report name is enforced server-side (DECISIONS.md D036) — `GET /analytics` only ever returns report ids the caller's role may open.

| Method | Path | Who (per report) | Notes |
|---|---|---|---|
| GET | `/workspaces/:id/analytics` | any member | `string[]` of report ids this member may open |
| GET | `/workspaces/:id/analytics/:report?from=&to=` | FINANCE_VIEWERS / FARM_REPORT_VIEWERS / AUDIT_VIEWERS, per report | `{ data, document }` — `document` is the generic `{title, workspaceName, period, generatedAt, sections[]}` shape (`report-table.ts`); `data` is the same report's typed payload (e.g. financial-summary's `trend[]` for charting) |
| GET | `/workspaces/:id/analytics/balance-sheet?asOf=` | FINANCE_VIEWERS | `asOf` instead of `from`/`to`, defaults to today (Pakistan time) |
| GET | `/workspaces/:id/analytics/trial-balance` | FINANCE_VIEWERS | no date parameter |
| GET | `/workspaces/:id/analytics/audit-log?from=&to=&action=` | AUDIT_VIEWERS | optional `action` filter |
| GET | `/workspaces/:id/analytics/:report/export?format=csv\|xlsx\|pdf&...` | same as the report | file download; `400` for an unknown report or format; audited (`report.export`) |

Report ids: `financial-summary`, `balance-sheet`, `trial-balance`, `land`, `farm-performance`, `animal-growth`, `audit-log`, `operations`.

## Offline Mode & Synchronization (Phase 13) — implemented

- **Idempotency** (DECISIONS.md D037): send `Idempotency-Key: <8-100 chars, [A-Za-z0-9_-]>` on any `POST`. Same key + same body within 7 days → the original response is replayed (header `Idempotent-Replayed: true`). Same key + different body → `422`. Malformed key → `400`.
- **Optimistic concurrency** (DECISIONS.md D038): send `If-Match: <updatedAt ISO string>` on `PATCH /workspaces/:id/farm/animals/:animalId` or `PATCH /workspaces/:id/land/:parcelId`. A stale value → `412 Precondition Failed`, nothing applied.

## Not yet implemented

Push notifications, cloud backup providers, voice notes, OCR beyond receipts, templates, and Phase 6 (security/QA hardening, production release). This file will be extended module-by-module as each is built — see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for current progress.
