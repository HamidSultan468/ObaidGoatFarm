# Architectural Decisions

This log records significant technical decisions for the Tangent Smart Manager platform, in chronological order. Each entry captures the decision, the reasoning, and known trade-offs. Do not delete past entries; append superseding decisions instead.

---

## 2026-11-03 — D001: Client stack — Flutter

**Decision:** Build all client applications (Android, iOS, Web, Windows) from a single Flutter/Dart codebase.

**Reasoning:**
- Single codebase compiles natively to all four required targets plus macOS/Linux at no extra cost.
- Strong fit for a data-dense, consistent financial UI across platforms (one widget tree, one design system).
- Mature offline-first story (local persistence + sync) needed for Phase 13 (Offline Mode & Synchronization).
- Chosen by the project owner over React/Next.js+Capacitor+Electron and React Native+Expo alternatives.

**Trade-offs accepted:**
- iOS builds/signing require a macOS machine (Xcode) — cannot be produced or verified from this Windows development machine. CI/CD or a Mac build host will be required before an iOS release.
- Flutter SDK was not present on the development machine as of this decision; see D002.

**Status:** Confirmed by project owner.

---

## 2026-11-03 — D002: Backend stack — NestJS (Node.js/TypeScript)

**Decision:** Backend API built on NestJS (TypeScript), using Prisma as the ORM against PostgreSQL.

**Reasoning:**
- NestJS gives a modular, testable architecture (modules/providers/guards) that maps cleanly onto the platform's many domains (accounting, goat farm, land, notifications, AI, etc.) required by CLAUDE.md §2 ("modular architecture and reusable components").
- Strong built-in support for DI, guards (RBAC), interceptors (audit logging), pipes (validation) — all required by CLAUDE.md §3/§4/§7.
- Prisma's `Decimal` type maps to PostgreSQL `numeric`, giving exact decimal arithmetic for money — never floating point, per CLAUDE.md §3.
- TypeScript end-to-end (shared DTO/type conventions) if a web client is ever added alongside Flutter.

**Trade-offs accepted:**
- Node/npm were present on the dev machine; PostgreSQL and Docker were not — see D003.

**Status:** Confirmed by project owner.

---

## 2026-11-03 — D003: Local development database provisioning

**Context:** Neither PostgreSQL nor Docker is installed on the current development machine. This blocks running real migrations and integration tests against Postgres until resolved.

**Status:** OPEN — pending project owner input. See IMPLEMENTATION_STATUS.md for the current workaround and open questions.

---

## 2026-11-03 — D004: Monetary value representation

**Decision:** All monetary amounts are stored as `Decimal` (PostgreSQL `numeric(18,4)`) via Prisma — never `Float`/`Double`, never JavaScript `number` for arithmetic. Application-layer money math goes through a single `Money` value-object/utility that wraps `decimal.js`, to centralize rounding rules and currency handling.

**Reasoning:** Direct mandate from CLAUDE.md §3 ("Never use floating-point arithmetic for financial calculations").

**Status:** Confirmed (derived from non-negotiable project requirement, not a discretionary choice).

---

## 2026-11-03 — D005: Multi-tenancy model

**Decision:** Row-level multi-tenancy — every tenant-scoped table carries a `workspaceId` foreign key, enforced both at the Prisma query layer (a request-scoped tenant-context provider) and re-checked in a guard on every request. No shared mutable state is trusted to isolate tenants on its own.

**Reasoning:** CLAUDE.md §4 mandates "strict multi-tenant data isolation" as a security requirement, and §14 requires it be explicitly tested. Row-level isolation with defense-in-depth (query layer + guard) is the standard approach for this scale and is straightforward to unit-test.

**Status:** Confirmed (initial design; revisit if a dedicated-schema-per-tenant model becomes necessary at scale).

---

## 2026-11-03 — D006: Starting scope for this engagement

**Decision:** Build Phase 02 (System Foundation) and Phase 04 (Dashboard shell) first, ahead of the deeper financial/farm/land business logic in Phases 05–07.

**Reasoning:** Chosen by the project owner. Gives a working, navigable skeleton (auth, tenant/workspace model, dashboard UI matching the approved reference image) that every subsequent module plugs into, rather than building a deep vertical slice first.

**Status:** Confirmed by project owner.

---

## 2026-11-03 — D007: Flutter SDK installed via manual no-admin method

**Context:** Chocolatey install (`choco install flutter`) failed — it requires administrator elevation, which was not available non-interactively in this environment.

**Decision:** Installed the Flutter SDK (3.47.9 stable, official `storage.googleapis.com` archive) manually to `%USERPROFILE%\develop\flutter`, added to the **user** PATH (not system/admin PATH). This is Flutter's officially documented no-admin-rights install method.

**Status:** Confirmed working — `flutter doctor` shows Windows desktop and Chrome/web targets fully functional (Visual Studio Build Tools + Windows SDK were already present on this machine). Android needs `cmdline-tools` (minor, not blocking). iOS cannot be built from Windows regardless (needs macOS/Xcode) — see D001.

---

## 2026-11-03 — D008: Prisma 7 driver-adapter configuration

**Context:** Prisma 7 (installed: `prisma`/`@prisma/client` 7.10.1) removed the Rust query engine in favor of a JS query compiler, and removed the `datasource.url` field from `schema.prisma` — connection configuration moved to a `prisma.config.ts` file, and `PrismaClient` now requires an explicit driver `adapter`.

**Decision:** Added `@prisma/adapter-pg` + `pg` + `dotenv`. `backend/prisma.config.ts` holds the CLI-facing `DATABASE_URL` (for `migrate`/`studio`/`seed`); `PrismaService` constructs `PrismaClient` with `new PrismaPg({ connectionString })` built from the same env var via `ConfigService`.

**Reasoning:** This is a mandatory breaking-change migration, not a discretionary choice — Prisma 7's old `datasource.url` schema syntax simply no longer works (confirmed via `prisma generate` failing with error code P1012).

**Status:** Confirmed — `prisma generate` succeeds. Still unverified against a live database (see IMPLEMENTATION_STATUS.md blockers).

---

## 2026-11-04 — D009: 6-phase delivery plan (regrouping CLAUDE.md's 15 phases)

**Decision:** Track delivery at a coarser 6-phase granularity (see [PHASES.md](PHASES.md)) for planning/reporting, while CLAUDE.md's original 15 phases remain the authoritative scope definition. Phase 1 = CLAUDE.md Phases 01–04 (Foundation & Core Platform).

**Reasoning:** Requested by the project owner. Phases 2–6 group naturally related CLAUDE.md phases (financial core; domain modules; engagement/automation; analytics/resilience; quality/release) so progress can be reported at a size that's meaningful without losing the detailed phase definitions underneath.

**Status:** Confirmed by project owner.

---

## 2026-11-04 — D010: TOTP/MFA library — `otplib` 13.x

**Decision:** Use `otplib`'s class-based `OTP` API (`new OTP({ strategy: 'totp' })`) for MFA secret generation, `otpauth://` URI generation, and code verification.

**Reasoning:** `otplib` 13.x rewrote its API from the older `authenticator` singleton to an explicit `OTP`/`TOTP` class — the old API (`authenticator.generateSecret()`, `.keyuri()`, `.check()`) no longer exists in the installed version and was caught via a real `tsc` error, not assumed from memory. The new API is otherwise the same well-established RFC 6238 implementation used by the previous major version.

**Status:** Confirmed — `backend/src/modules/auth/mfa.service.ts`, type-checks clean.

---

## 2026-11-04 — D011: Secrets encryption — AES-256-GCM via a dedicated `EncryptionService`

**Decision:** A single `EncryptionService` (`backend/src/common/crypto/encryption.service.ts`), built on Node's built-in `crypto` module (no new dependency), provides `encrypt`/`decrypt` for any secret that must be recovered in plaintext later — currently only the MFA TOTP secret (`User.mfaSecretEncrypted`). The AES key comes from a required `ENCRYPTION_KEY` env var (32 bytes, hex), validated at boot.

**Reasoning:** CLAUDE.md §4 requires encrypting sensitive data and AI API credentials at rest. AES-256-GCM (authenticated encryption, random IV per value) is the standard choice; centralizing it in one service — rather than ad hoc `crypto` calls per feature — means Phase 11's AI/WhatsApp provider credentials can reuse the same service later instead of reinventing it.

**Status:** Confirmed — unit-testable in isolation (no DB dependency), used by `MfaService`.

---

## 2026-11-04 — D012: Step-up MFA login flow (challenge token, not account-wide session block)

**Decision:** When a user with `mfaEnabled` logs in, `POST /auth/login` returns `{ mfaRequired: true, mfaToken }` (a short-lived, purpose-scoped JWT) instead of real session tokens. `POST /auth/mfa/login` exchanges that token + a TOTP code for real access/refresh tokens. The challenge token is signed with the same JWT access secret but carries a `purpose: 'mfa_challenge'` claim that `MfaService.verifyChallenge` checks explicitly — it is rejected everywhere else, including by the normal `JwtStrategy`, since it fails that strategy's user-lookup-based validation path by design (it's never sent as a bearer token).

**Reasoning:** This is the standard, secure shape for step-up MFA (password proves identity, TOTP proves possession, neither alone issues a session) and reuses the existing JWT signing infrastructure rather than adding a second token system.

**Status:** Confirmed — type-checks clean; not yet integration-tested against a live database (see IMPLEMENTATION_STATUS.md blockers).

---

## 2026-11-04 — D013: "Sessions" are active RefreshTokens, not a separate UserDevice-backed model (yet)

**Context:** The schema has both `RefreshToken` (real, populated on every login) and `UserDevice` (defined but nothing writes to it — the client doesn't yet send device metadata beyond an optional free-text `X-Device-Id` header).

**Decision:** `GET /auth/sessions` / `DELETE /auth/sessions/:id` operate on active (non-revoked, unexpired) `RefreshToken` rows. The Flutter Settings screen's "Active sessions" section is built on this.

**Reasoning:** Building a UserDevice-backed view with friendly device names/platforms would require the client to collect and send that metadata first — a real but separate piece of work. Sessions-as-refresh-tokens is honest, fully real data (not a stub), and already gives a user the core capability (see and revoke their active logins) without blocking on that follow-up.

**Status:** Confirmed as the current scope. `UserDevice`-based enrichment remains a tracked gap (see IMPLEMENTATION_STATUS.md).

---

## 2026-11-04 — D014: Localization scope — core screens translated, not exhaustive

**Decision:** Real ARB-based localization (`flutter gen-l10n`) is wired end-to-end — `AppLocalizations`, a working language switcher in Settings, and English/Urdu translations for the login flow (including MFA challenge), sidebar navigation, dashboard title, settings section headers, and workspace creation. Deeper copy (dialog bodies in MFA/Admin screens, error message strings from the backend, module placeholder subtext) remains English-only.

**Reasoning:** Demonstrates genuine, verified (automated RTL test — see `app/test/l10n_test.dart`) localization infrastructure and covers the screens every user sees first, rather than claiming full-app translation that isn't actually done. CLAUDE.md's rule against overstating completion applies to localization coverage the same as any other feature.

**Status:** Confirmed, partial by design — see FEATURES.md for the exact boundary.

---

## 2026-11-05 — D015: Single `LedgerService.postEntry()` as the only write path to the ledger

**Decision:** Every financial record — manual entries, the Income/Expense/Transfer convenience endpoints, recurring template runs, and (when built) Phase 06/07 farm/land transactions — posts through one `LedgerService.postEntry()` method, never writes `JournalEntry`/`JournalLine` rows directly.

**Reasoning:** Centralizing balance validation (`assertBalanced`), approval-threshold routing, and receipt-code issuance in one place means every caller gets these guarantees automatically instead of each feature re-implementing (and potentially getting wrong) the double-entry invariant. This was already the stated intent in ACCOUNTING.md before any code existed — this decision confirms it held through implementation.

**Status:** Confirmed — `TransactionsService` and `RecurringService` both depend on `LedgerService` rather than touching Prisma's `journalEntry`/`journalLine` models directly.

---

## 2026-11-05 — D016: Approval threshold is a single per-workspace amount, not per-category

**Decision:** `Workspace.approvalThreshold` (nullable `Decimal`) is the only approval control. An entry whose debit total meets or exceeds it is created `PENDING_APPROVAL`; there's no per-account, per-category, or per-approver-chain configuration.

**Reasoning:** CLAUDE.md asks for "approvals" without specifying granularity. A single workspace-wide threshold is the simplest version that's still genuinely useful (catches large transactions regardless of category) and was buildable without a workflow-engine-shaped schema. Documented here as a deliberate scope boundary, not an oversight — see ACCOUNTING.md "Known simplifications."

**Status:** Confirmed as current scope; revisit if real usage shows a need for per-category rules.

---

## 2026-11-05 — D017: Recurring transactions use explicit "run now," not unattended cron

**Decision:** `RecurringTemplate.nextRunDate` exists and advances correctly on each run, but nothing posts automatically — a user (or, later, an external scheduler) must call `POST .../recurring-templates/:id/run-now`.

**Reasoning:** Unattended execution needs job-scheduler infrastructure (a cron runner, a queue, or a platform cron trigger) that doesn't exist in this environment and is out of scope for the accounting domain model itself. Building the template + manual trigger now means the data model and posting logic are correct and ready — wiring up a scheduler later is additive, not a rework.

**Status:** Confirmed as current scope — see ACCOUNTING.md "Known simplifications" and IMPLEMENTATION_STATUS.md.

---

## 2026-11-05 — D018: Cash flow report is simplified (net CASH/BANK movement only)

**Decision:** The cash-flow report sums the change in CASH/BANK-kind accounts over a period and splits it into total inflows/outflows. It does not categorize movements into operating/investing/financing activities (the standard three-section cash flow statement).

**Reasoning:** A fully categorized cash flow statement requires classifying every account (or every transaction type) into one of the three categories — a real design decision that needs domain input (e.g. is a supplier payment always "operating"? is a land purchase "investing"?) better made once Phase 07 (land) exists and real categorization needs are concrete, rather than guessed now.

**Status:** Confirmed as a documented simplification, not a hidden gap — the report's own field names ("net change," "inflows," "outflows") don't claim to be more than they are.

---

## 2026-11-05 — D019: QR receipt verification is public and minimal-disclosure

**Decision:** `GET /receipts/verify/:code` requires no authentication and returns only `{ documentNumber, memo, amount, postedAt, workspaceName }` — never the internal entry id, the account names involved, or anything else about the issuing workspace.

**Reasoning:** The entire point (matching the reference dashboard mockup's "QR Verified Receipt" card) is that a customer holding a paper/phone receipt can verify it's genuine without an account or credentials. Making it public is the feature, not a gap — but that means the response must be scoped tightly to what a receipt legitimately shows, which is why it's a dedicated minimal DTO rather than exposing the `JournalEntry` model.

**Status:** Confirmed — `ReceiptsService.verify()` hand-picks its return fields rather than serializing the Prisma model.

---

## 2026-11-04 — D020: CORS allows any localhost origin in development only

**Context:** The first live browser run failed to log in with "Could not reach the server." Root cause: `CORS_ORIGIN` was `http://localhost:5173`, but `flutter run -d chrome` serves on a different (often arbitrary) port each run, so every browser request was blocked by CORS preflight.

**Decision:** `main.ts` resolves the CORS origin per environment — when `NODE_ENV=development`, any `http(s)://localhost:<port>` or `127.0.0.1:<port>` origin is allowed via a regex; in every other environment the explicit `CORS_ORIGIN` allowlist is enforced unchanged.

**Reasoning:** Keeps production strict (no wildcard, no regex) while removing a dev-loop failure that would recur on every port change. Verified with a real preflight: `OPTIONS /auth/login` from `Origin: http://localhost:8766` now returns `204` with `Access-Control-Allow-Origin` echoed.

**Status:** Confirmed.

---

## 2026-11-04 — D021: Money display is exact and shows each account's natural balance

**Context:** The first live dashboard showed raw ledger strings (`$5000.0000`), and the Bank & Accounts screen showed Sales Income as `-5,000.00` — correct bookkeeping (credits are negative in the debit-positive ledger) but reads as a loss to a non-accountant.

**Decision:** Two client-side display helpers in `app/lib/core/accounting/money_format.dart`:
- `formatMoney()` — rounds the server's `numeric(18,4)` string to 2 places with thousands grouping using **BigInt minor-unit arithmetic, never `double`**, so even display rounding follows DECISIONS.md D004. Unit-tested, including a value beyond double precision.
- `naturalBalance()` — flips the sign for credit-normal account types (LIABILITY, EQUITY, INCOME) for display only. Stored data and every API response are unchanged.

**Status:** Confirmed — verified live (`$5,000.00`; Sales Income `5,000.00`) and by unit tests.

---

## 2026-11-04 — D022: Request validation never converts types implicitly

**Context:** A Phase 3 live test sent a weight as the JSON number `33.5` and it was accepted. `ValidationPipe` had `enableImplicitConversion: true`, which turned the number into the string `"33.5"` before the "decimal string" regex ran. The same hole existed for every money `amount`.

**Decision:** `enableImplicitConversion: false`. Money, weights and areas must arrive as strings; numbers in those fields are rejected with `400`. The only query DTO in use has string fields, so nothing relied on conversion.

**Status:** Confirmed — verified live for money, weights and land area.

---

## 2026-11-04 — D023: Marla = 272.25 sq ft (revenue standard)

**Context:** Land area conversions need a marla size. Punjab revenue records (agricultural land) use 272.25 sq ft (1 kanal = 20 marla = 5,445 sq ft; 1 acre = 8 kanal = 43,560 sq ft). Many urban housing schemes use 225 sq ft.

**Decision:** 272.25 sq ft, since this platform's land module targets agricultural land. Area is stored canonically in sq ft next to the user's original value and unit, so a future per-workspace marla setting can recompute display values without data loss.

**Status:** Confirmed as the default — **business owner to confirm** whether any of their land is measured in 225 sq ft marla.

---

## 2026-11-04 — D024: The ledger checks ownership of every record an entry references

**Context:** Building animal/land tags exposed that `LedgerService.postEntry` connected accounts and contacts by id without checking their workspace: a member of workspace B could post into workspace A's account.

**Decision:** Before posting, every referenced account (must also be active), contact, animal and land parcel is counted with `workspaceId` in the filter; any mismatch is `400` without revealing whether the foreign id exists. This sits in the single write path, so income, expense, transfer, manual, approved and recurring entries are all covered.

**Status:** Confirmed — verified live.

---

## 2026-11-04 — D025: Documents are stored encrypted on local disk; type is sniffed, not trusted

**Context:** Phase 08 needs private file storage now; cloud providers are Phase 10.

**Decision:** Files are encrypted with the existing AES-256-GCM key (`EncryptionService.encryptBuffer`) and written under `STORAGE_DIR/<workspaceId>/<uuid>.bin`; the database keeps only metadata and a SHA-256 of the plaintext. Only JPEG, PNG, WEBP and PDF are accepted, detected from magic bytes (SVG/HTML are excluded as script carriers). Limit 10 MB. The storage layer is isolated in `DocumentsService` so an S3-compatible or cloud backend can replace the disk calls in Phase 10.

**Status:** Confirmed. Note: `STORAGE_DIR` must be included in backups (Phase 10) — losing it loses the files, and losing `ENCRYPTION_KEY` makes them unreadable.

---

## 2026-11-04 — D026: Migrations are generated with `migrate diff` in non-interactive shells

**Context:** `prisma migrate dev` refuses to run without an interactive terminal (the automation environment).

**Decision:** Generate SQL with `prisma migrate diff --from-config-datasource --to-schema prisma/schema.prisma --script` into a new timestamped folder, review it, then apply with `prisma migrate deploy`. The result is an ordinary migration folder, identical in effect to `migrate dev`.

**Status:** Confirmed — used for `20261104120000_phase3_farm_land_documents`.

---

## 2026-11-04 — D027: In-process scheduler for reminders, email delivery and daily backups

**Decision:** `@nestjs/schedule` runs notification rules every 10 minutes, the email worker every minute, and backups daily at 02:00 inside the backend process. One instance is assumed; the per-user `dedupeKey` (reminders) and the conditional claim on each delivery make a second instance safe anyway.

**Status:** Confirmed. A dedicated job runner (queue) can replace it when there are many workspaces.

---

## 2026-11-04 — D028: Email via SMTP is optional; push waits for Firebase

**Decision:** Email uses any SMTP server configured in `SMTP_*`; without it, email options are hidden/disabled and nothing pretends to send. Push notifications are not built: they need a Firebase project (and Apple push credentials), which are the owner's accounts.

**Status:** Confirmed.

---

## 2026-11-04 — D029: Backups restore only into a new workspace

**Context:** "Verify integrity before restoration" and immutable posted records rule out overwriting a live workspace.

**Decision:** A restore creates a brand-new workspace: every row gets a new id with all references remapped, in one transaction; files are re-encrypted; receipt verification codes (globally unique) are not copied. Backups are encrypted with a key derived (HKDF) from `ENCRYPTION_KEY`, so they can only be restored on a server with the same key. Restoring an uploaded file requires being OWNER of the source workspace (or Super Admin Owner), so a leaked file is useless to other accounts.

**Status:** Confirmed — verified live (identical trial balance and P&L after restore, original untouched).

---

## 2026-11-04 — D030: AI = Claude via the official SDK, drafts only

**Decision:** Anthropic Claude through `@anthropic-ai/sdk`, default model `claude-opus-5-5` (owners can choose Sonnet/Haiku 5.5), structured JSON output, effort `low` (short extraction), and Anthropic's server-side refusal fallback (`fallbacks: "default"`). Keys are per workspace, encrypted, tried in priority order (failover) with monthly limits. The model's output is untrusted: every id is checked against the workspace's records and the result is only ever a PENDING draft. Other vendors plug in behind the same provider call.

**Status:** Built; verified with real (rejected) calls. **Needs a real API key to verify successful extraction.**

---

## 2026-11-04 — D031: Draft approval reuses the manual-entry services and is claimed atomically

**Decision:** Approving a draft validates it with the same DTOs and calls the same services as manual entry (so the ledger, approval threshold and tenant checks apply). `PENDING → APPROVED` is one conditional update; if creating the record fails the draft returns to PENDING.

**Status:** Confirmed — three simultaneous approvals posted exactly one entry.

---

## 2026-11-04 — D032: WhatsApp via the official Cloud API, linked phones only

**Decision:** Meta's WhatsApp Business Cloud API. Webhooks are accepted only with a valid `X-Hub-Signature-256` over the raw body (constant-time compare). A phone is trusted only after the user sends a one-time code (hashed, 15 minutes, 5 attempts). Text messages become drafts through the AI pipeline; voice notes get a "text only" reply until a speech-to-text provider is chosen. Replies are best-effort and logged.

**Status:** Built; verified with signed test webhooks and real (rejected) Graph API calls. **Needs a Meta Business account, a number and a public HTTPS URL to go live.**

---

## 2026-11-04 — D033: Field-level errors travel in `details`

**Decision:** The global error filter puts class-validator messages, or a service's explicit `errors` list, into `details`. The Flutter error helper shows `message` plus `details`, and ignores the generic "Bad Request Exception" text.

**Status:** Confirmed.

---

## 2026-11-04 — D034: The launcher's web server always revalidates

**Context:** Flutter's `main.dart.js` has no content hash; a one-hour cache kept users on the old app after a rebuild.

**Decision:** `Cache-Control: no-cache` with an ETag (size + modified time); unchanged files return 304.

**Status:** Confirmed.

---

## 2026-11-04 — D035: Workspace lists include the caller's role

**Decision:** `GET /workspaces` returns `myRole` per workspace so the app can show owner/admin controls. It only affects what is shown; every route still checks permissions on the server.

**Status:** Confirmed.

---

## 2026-11-04 — D036: Financial report endpoints are FINANCE_VIEWERS-only

**Context:** Building the Phase 12 analytics module's role table (`REPORT_ACCESS`) against the *existing* Phase 2 `reports.controller.ts` (Profit & Loss, trial balance, cash flow) exposed that those endpoints had never had a `RolesGuard` — any workspace member, including STAFF/VIEWER, could read full financial reports.

**Decision:** `reports.controller.ts` now requires `RolesGuard` + `@Roles(...FINANCE_VIEWERS)` (OWNER/ADMIN/MANAGER), the same rule the new `/analytics/*` endpoints use for `financial-summary`/`balance-sheet`/`trial-balance`/`land`. STAFF and VIEWER can still see farm-only reports (`FARM_REPORT_VIEWERS`); only OWNER/ADMIN can see the audit log (`AUDIT_VIEWERS`).

**Reasoning:** Financial detail (account balances, income/expense by category) is not something every workspace member should see by default — consistent with how `animalId`-tagged profit is already hidden from STAFF elsewhere (D024's ownership checks address a different gap: cross-tenant access, not cross-role visibility within a tenant).

**Status:** Confirmed. Verified live: a STAFF token gets `403` on both the new analytics endpoint and the pre-existing P&L endpoint; an OWNER/ADMIN/MANAGER token succeeds on both.

---

## 2026-11-04 — D037: Idempotency keys, not server-side request deduplication by content

**Context:** A client that submits a write (income/expense/etc.) and loses the response before it arrives — a dropped connection, a timeout — cannot tell whether the write actually posted. Retrying blindly risks posting it twice; not retrying risks losing it if it never posted.

**Decision:** The client generates a stable key per logical write attempt (`Idempotency-Key` header, 8–100 chars) and sends the *same* key on every retry of that same attempt. The server caches `(user, key) → (request hash, response)` for 7 days: a retry with a matching key and matching body replays the cached response; a matching key with a *different* body is rejected `422` (a key is a promise about one specific request, never silently reused for a different one); a request that failed before completing does not consume its key, so a corrected retry still succeeds.

**Reasoning:** Deduplicating by request content alone (e.g. "same amount + same accounts within N seconds") is unreliable — two genuinely separate 500.00 expenses to the same account in the same minute are a normal occurrence, not a duplicate. A client-generated key makes "this is the same attempt" an explicit, unambiguous signal instead of a heuristic guess.

**Status:** Confirmed. Verified live (`reports-sync.e2e.mjs`): replay returns the identical entry id; 5 concurrent submissions with one key post exactly once; a malformed key is rejected `400`; keys are scoped per user.

---

## 2026-11-04 — D038: Optimistic concurrency (`If-Match`/412) over last-write-wins, for editable records

**Context:** `Animal` and `LandParcel` have a handful of mutable fields (health status, lease status) that two people could edit around the same time — the offline outbox in particular can retry an edit well after it was queued, by which point the record may have changed.

**Decision:** The client sends the record's `updatedAt` (from its last read) as an `If-Match` header on `PATCH`. If the server's current `updatedAt` doesn't match, the request is refused `412 Precondition Failed` and nothing is applied; the client reloads and the user retries deliberately. This is why the Flutter offline write-outbox (OFFLINE_SYNC.md) deliberately never queues *edits* — only new writes (income/expense/transfer/weight/health) go through the outbox; a status change is sent immediately or not at all, so a queued-then-stale edit can never silently apply.

**Reasoning:** Last-write-wins would satisfy CLAUDE.md's letter ("never silently overwrite a posted financial record" — these aren't posted financial records) but violates its spirit for any shared mutable state: a queued offline edit landing minutes later and silently erasing someone else's more recent change is exactly the kind of silent overwrite the project is trying to avoid everywhere, not only in the ledger.

**Status:** Confirmed. Verified live on both `Animal.update` and `LandParcel.update`: a stale `If-Match` is refused `412` and the current value is unchanged; a current `If-Match` succeeds.

---

## 2026-11-04 — D039: Hand-written OOXML Excel exporter instead of `exceljs`

**Context:** `exceljs` (evaluated for the Phase 12 Excel export) pulls in `archiver`/`archiver-utils`, which in turn pull in vulnerable transitive versions of `minimatch` and `uuid` — `npm audit` flagged them.

**Decision:** Excel export is a small, fully hand-written `.xlsx` writer (`backend/src/modules/analytics/exporters/xlsx.exporter.ts`) built on Node's built-in `zlib` (`deflateRawSync`/`crc32`) for the OOXML zip container — no external dependency at all for this feature.

**Reasoning:** CLAUDE.md §2 ("avoid unnecessary dependencies") and §4 (security) both point the same direction here: the feature's actual requirement — one worksheet per report section, frozen header row, money/decimal number formats, bold totals — is small enough that writing it directly removes an entire dependency tree (and its future vulnerabilities) rather than trading one set of CVEs for a pinned, audited version that will drift again.

**Status:** Confirmed. `npm audit --omit=dev`: 0 vulnerabilities. Output independently validated by opening generated files with Python's `openpyxl` (not just checking that bytes were produced).

---

## 2026-11-04 — D040: KPI card label text is solid white, not `white70`

**Context:** A Phase 14 accessibility pass computed WCAG contrast ratios for every color pair in `AppColors`. The dashboard's KPI cards (`kpi_card.dart`) render their label ("Income", "Expenses", "Net Profit", "Bank Balance") in `Colors.white70` at 13px/w500 over the four accent colors (`incomeGreen`/`expenseRed`/`profitBlue`/`balancePurple`) — measured contrast 2.30–2.88:1, below even the 3:1 minimum for large text, let alone the 4.5:1 required for text this size.

**Decision:** The label now renders in solid `Colors.white`, raising contrast to 3.18–4.55:1 depending on the card color. The bold 22px value text was already solid white and already passed the large-text 3:1 threshold.

**Known remaining gap:** Solid white still falls short of the full 4.5:1 normal-text threshold on `incomeGreen` (3.18:1), `accentBlue` (3.21:1), `profitBlue` (3.68:1) and `expenseRed` (3.91:1) — only `sidebarNavy`/`primaryBlue`-family combinations clear 4.5:1 outright. Reaching full AA for this label at its current size would require either darkening the four accent colors or enlarging/bolding the label past the "large text" threshold (~18.7px bold) — both are visual-design changes to the approved reference palette, out of scope for this QA pass. Tracked as a follow-up for a dedicated design/accessibility pass, not silently left undocumented.

**Also checked, no change needed:** `AppColors.warning` is defined but not referenced anywhere (its 2.15:1 contrast on white is moot). `AppColors.borderLight`/`borderDark` (1.23:1 on their card background) are used for dividers, card outlines, and the *unfocused* input-field border, where Material's filled background already provides most of the boundary cue; flagged for the same future design pass rather than changed blindly here, since `dividerColor` feeds the entire app's visual language.

**Status:** Confirmed (the label fix). The remaining gap and the border-color question are open follow-ups, not silently dropped — see FEATURES.md/IMPLEMENTATION_STATUS.md Phase 6.

---

## 2026-11-04 — D041: `JwtStrategy` rejects any token carrying a `purpose` claim

**Context:** A Phase 14 security sweep found that the MFA challenge token (`MfaService.issueChallenge`, payload `{sub, purpose: 'mfa_challenge'}`, signed with the same `jwt.accessSecret` as a real access token) worked as a full bearer token on every protected route. `JwtStrategy.validate()` only ever read `payload.sub` — it never checked `purpose` — so a stolen or logged challenge token (issued the instant a password is correct, *before* the TOTP code is checked) granted complete account access, bypassing MFA entirely. SECURITY.md had documented the intended behavior ("the challenge token is rejected everywhere else") but the code didn't actually implement that check outside `MfaService.verifyChallenge` itself.

**Decision:** `JwtStrategy.validate()` now throws `UnauthorizedException` immediately if the decoded payload carries a `purpose` claim at all, before even looking up the user. Real access tokens are signed with `{sub, email}` only and never carry `purpose` (verified: the only other `purpose`-carrying token in the codebase is the MFA challenge token itself), so this closes the bypass with no effect on normal sessions.

**Reasoning:** This is the textbook risk of two token types sharing one signing secret and one verification path: the JwtStrategy's job is "is this signature valid," not "is this *token* allowed to do this" — the second question needs an explicit claim check, which this adds as a blanket rule (reject any purpose-scoped token as a bearer token) rather than special-casing `mfa_challenge` specifically, so any *future* purpose-scoped token (e.g. a password-reset token) is safe by default without remembering to update this guard again.

**Status:** Confirmed. Verified live (`backend/scripts/e2e/security-qa.e2e.mjs`): an MFA challenge token used as `Authorization: Bearer <mfaToken>` against `GET /auth/me` now returns 401 (previously 200). Regression: `jwt.strategy.spec.ts` (3/3) plus the full existing auth/MFA live suite still passes.

---

## 2026-11-04 — D042: `CORS_ORIGIN` is a required, validated environment variable outside development

**Context:** The same Phase 14 sweep found `main.ts`'s `resolveCorsOrigin()` fell back to `true` (allow every origin) whenever `CORS_ORIGIN` was unset outside development — and `CORS_ORIGIN` wasn't in `env.validation.ts`'s schema at all, so nothing would have caught a production deploy that forgot to set it. Every *other* required secret (`JWT_ACCESS_SECRET`, `ENCRYPTION_KEY`, ...) already fails the app's boot rather than running half-configured; CORS was the one exception.

**Decision:** `env.validation.ts` now requires `CORS_ORIGIN` whenever `NODE_ENV !== 'development'` (`@ValidateIf`), with a message that says why. `main.ts`'s fallback changed from `?? true` (wildcard-allow) to `?? []` (deny-all) as defense in depth, since validation should make that branch unreachable in practice.

**Reasoning:** Matches this project's existing fail-fast posture (CLAUDE.md §4) instead of being a silent exception to it — a missing production secret should stop the app from starting, never quietly relax a security control.

**Status:** Confirmed. `env.validation.spec.ts` (3/3): development doesn't require it (D020's any-localhost rule applies instead), production without it throws, production with it starts normally.

---

## 2026-11-05 — D043: The dashboard matches the reference mockup's real functionality, not its marketing flourishes

**Context:** Rebuilding the dashboard against `Tangent Smart Manager Dashboard.png` (the originally approved reference image). That image is a marketing/concept render: alongside real-looking cards it also shows a phone mockup and a promotional side panel ("Your Smart Life, Our Priority"), a calculator tile, a voice-command tile, a row of record-type templates (Sales Invoice, Purchase Invoice, ...), a specific fabricated QR-verified receipt (a named client, a specific amount), and an Admin Control Panel full of feature on/off toggles (AI Assistant, Multi-Client System, Advanced Reports, ...).

**Decision:** Rebuilt every panel that maps to a real, already-built feature (KPI cards, a real Financial Overview chart, an expanded real Quick Actions grid, a real inline Notifications panel, Recent Transactions, Goat Farm stats, Cloud Backup Status) to match the mockup's layout and visual weight. Left out, deliberately: the phone mockup and promotional panel (not an app screen at all), the calculator and voice-command tiles (no such feature exists anywhere in the app), the record-templates row (TEMPLATES.md: not built), the specific demo QR receipt (would be fabricated data on a real dashboard), the Admin Control Panel's feature toggles (ADMIN_CONSOLE.md: feature flags/API settings/themes/logs are not built — only workspace/user activation and global roles are, and those already have their own real screen), and the four cloud-provider icons on the backup card (BACKUP_STORAGE.md: Drive/OneDrive/Dropbox/S3 adapters are not built — only local disk storage is).

**Reasoning:** CLAUDE.md §2 is explicit: never introduce mock functionality into production modules, never placeholder a completed feature. A toggle that doesn't toggle anything, or a receipt that was never actually issued, would be exactly that — regardless of how closely it matched a reference image. The instruction to "make it match the image" is satisfied by matching its genuine structure and style with genuine data, not by copying content that has nothing behind it.

**Status:** Confirmed. Verified live in Chrome against the real backend and database: KPI cards, Financial Overview chart (period switch verified: This month/Last 3 months/This year all fetch and render), Quick Actions (all 6 tiles call the real feature they name), Notifications panel, Recent Transactions table, Goat Farm stats, Cloud Backup Status badge — no console errors. `flutter analyze` 0 issues, `flutter test` 63/63.

---

## 2026-11-05 — D044: Docker install succeeded; its WSL2 backend is blocked on a BIOS setting, not software

**Context:** Attempting to set up this machine for Phase 15's Docker-based deployment prep. This session has no administrator token (confirmed: `IsInRole(Administrator)` is `False`, and even a read-only `Get-WindowsOptionalFeature` query fails with "requires elevation"). Despite that, `winget install Docker.DockerDesktop` and `wsl --install --no-distribution` both completed successfully (exit 0) — evidently neither needed an interactive elevation prompt in this environment. `wsl --status` afterward reported: "WSL2 is unable to start since virtualization is not enabled on this machine... ensure virtualization is turned on in your computer's firmware settings." `Get-CimInstance Win32_ComputerSystem` confirms this is a real Dell OptiPlex 7010 desktop (not a VM), a model generation where Intel VT-x commonly ships disabled in BIOS by default.

**Decision:** No further software action is possible here — enabling CPU virtualization (Intel VT-x) requires physically rebooting into BIOS/UEFI setup (on Dell desktops, typically F2 at boot) and enabling it there, then restarting Windows. This is recorded as the single concrete blocking step for Phase 15's Docker work, rather than a vague "Docker isn't installed" note.

**Status:** Open — needs the machine's owner to perform the BIOS change; nothing else in Phase 15's Docker prep (Dockerfile, docker-compose.yml, the CI workflow) is blocked on this specifically, since CI runs on GitHub's own runners, not this machine.

---

## 2026-11-05 — D045: Device metadata is client-reported and optional, joined by the same `deviceId` the session already carries

**Context:** "Active sessions" (`/auth/sessions`) showed only an opaque `deviceId` — real device/session management (FR-3.5) needs a friendly name and platform. A `UserDevice` table already existed in the schema for this but was never wired to anything, and had no column linking it back to a `RefreshToken.deviceId`.

**Decision:** The Flutter client generates a stable per-install id once (`core/api/device_info.dart`, stored via the existing secure `TokenStorage`) and reports it plus a platform-derived name (`defaultTargetPlatform`/`kIsWeb` — never `dart:io`'s `Platform`, which doesn't compile for the web build target) on every request via `X-Device-Id`/`X-Device-Name`/`X-Device-Platform` headers. `AuthService.issueTokens` upserts a `UserDevice` row (added `deviceId` column, `@@unique([userId, deviceId])`) only when all three are present; `listSessions` left-joins on that id. A session from before this existed, or from a client that omits the headers, simply shows the raw `deviceId` (or "Unknown device") — never an error.

**Reasoning:** No new dependency (`device_info_plus` would give a real model name but adds a plugin this project otherwise doesn't need) and no breaking change to existing sessions. Headers rather than a login-body field, to match the existing `X-Device-Id` convention and so refresh/other calls can carry the same identity without threading it through every DTO.

**Status:** Confirmed. Verified live: a session carries the exact name/platform sent at login; a session from a login with no device headers (or predating this change) degrades to `null`/`null` rather than erroring.

---

## 2026-11-05 — D046: Every money field returned by the API is Money-formatted, even ones that were never user-facing before

**Context:** Building the Budgets/Recurring Templates Flutter screens surfaced that `Budget.amount` and `RecurringTemplate.amount` were returned as whatever Prisma's `Decimal` JSON serialization happened to produce (e.g. `"1000"` instead of `"1000.0000"`) — the only money fields in the whole API that hadn't been routed through `Money.toFixed(4)` before being sent, because until now nothing displayed them directly.

**Decision:** `BudgetsService`/`RecurringService` now map every response through a small `withExactAmount()` helper (`Money.from(...).toFixed(4)`) before returning it — create, list, and the nested budget inside `getProgress`.

**Reasoning:** DECISIONS.md D004's rule ("never float, always exact") is about more than storage — an inconsistently-formatted decimal string is a smaller version of the same risk: a client that assumes a fixed 4-decimal shape (as every other money field in this API already guarantees) could parse `"1000"` incorrectly. Found by a live E2E assertion expecting the established shape, not by inspection — a reminder that the Flutter side exercising a backend response for the first time is itself a useful check.

**Status:** Confirmed. `completeness.e2e.mjs` asserts the exact 4-decimal form on both endpoints.

---

## 2026-11-05 — D047: Animal profile photo reuses the existing Attachment pipeline instead of a new upload path

**Context:** Request to add animal photos. The app already has a generic, encrypted, authenticated attachment system (`Attachment`/`AttachmentModule.ANIMAL`) for arbitrary animal documents.

**Decision:** Added `Animal.photoAttachmentId String? @unique`, a one-to-one relation to `Attachment` (`onDelete: SetNull`). No new upload endpoint: the client uploads an image via the existing `POST /workspaces/:id/attachments` (module=ANIMAL, recordId=animal.id), then `PATCH`es the animal with `{ photoAttachmentId }`. The service (`AnimalsService.assertPhotoAttachment`) requires the referenced attachment to belong to this workspace, be `module=ANIMAL`, and have `recordId` equal to this animal's id — an attachment can't be "borrowed" as another animal's or a GENERAL document's photo. `photoAttachmentId: null` clears it.

**Reasoning:** No parallel photo-storage/encryption/download pipeline to maintain; the photo is always one of the animal's own already-authorized documents. `onDelete: SetNull` means deleting the chosen attachment (e.g. from "Photos & documents") never blocks the delete — it just un-sets the profile photo.

**Status:** Confirmed. Live E2E (`scripts/e2e/animal-photo.e2e.mjs`, 11/11 passing) covers set/clear/cross-animal-rejection/GENERAL-rejection/SetNull-on-delete. Flutter: `AnimalPhotoAvatar` (detail screen, tap to change) and `AnimalThumbnail` (herd list row) both fetch bytes via the existing authenticated `attachmentBytesProvider`.

---

## 2026-11-05 — D048: Staff tab — any active member may list members; only OWNER/ADMIN may change a role or remove someone

**Context:** Request to add a "Staff" tab. The workspace already had `inviteMember`; listing/role-change/removal didn't exist yet.

**Decision:** `GET /workspaces/:id/members` (list) requires only `WorkspaceGuard` (any active member may view who else has access). `PATCH /workspaces/:id/members/:membershipId/role` and `DELETE /workspaces/:id/members/:membershipId` require `RolesGuard` + `@Roles('OWNER','ADMIN')`. OWNER is excluded from `UpdateMemberRoleDto`'s assignable roles (ownership transfer is out of scope, a separate sensitive operation) and from both endpoints' targets (the owner's own role can't be changed and the owner can't be removed through this route). A caller can't change or remove their own membership either, regardless of role. Removal is `isActive: false`, never a hard delete, so tagged history survives.

**Reasoning:** Matches every other "removal" in this codebase (accounts, workspaces, users) — soft-deactivate only. Blocking self-modification avoids a caller locking themselves out or orphaning the workspace by accident.

**Status:** Confirmed. Live E2E (`scripts/e2e/workspace-members.e2e.mjs`, 16/16 passing). Flutter: `StaffScreen` (new `/staff` sidebar tab) — read-only for everyone, role-change/remove controls only for OWNER/ADMIN callers viewing someone else's row.

---

## 2026-11-05 — D049: Admin Console's Workspaces/Users tabs resolve detail server-side rather than the client making N follow-up calls

**Context:** Request to make the Admin Console show "all details" (sari details). `AdminService.listWorkspaces`/`listUsers` returned only the bare row (name, active flag, raw member count).

**Decision:** `listWorkspaces` now includes each workspace's active memberships (to compute an owner email/name and a role breakdown like `{OWNER: 1, STAFF: 2}`) plus `_count` of animals/land parcels/journal entries, all in one query. `listUsers` now includes each user's active memberships (to list every workspace they belong to and their role there) in one query. No new endpoints — same two routes, richer payload.

**Reasoning:** The Admin Console is read by a human super admin skimming a list; computing the summary server-side (one query with `include`) is simpler and cheaper than having the Flutter client fire a follow-up request per row to resolve "who owns this" or "what workspaces does this user have."

**Status:** Confirmed. Verified live against the real database (`node -e` fetch of both endpoints showing the new fields); full `completeness.e2e.mjs` system-log suite (which shares `AdminService`) still 23/23.

---

## 2026-11-05 — D050: A second selectable theme ("Professional") added alongside "Modern Blue," which stays the default

**Context:** Request that the existing ("basic") design stay as it is, with a second, more professional-looking design also available — not a replacement.

**Decision:** `AppThemeVariant` enum (`modernBlue`, `professional`) replaces the old single `AppTheme.light()/dark()` pair. Each variant builds its own `ThemeData` (seed color, surface/card/border/text colors, card/input corner radius, headline weight) and attaches its own `AppBrandColors` — a `ThemeExtension` carrying the colors that used to be hardcoded `AppColors.*` constants directly in widget code (sidebar, sidebar-active, income/expense/profit/balance). "Professional" is charcoal sidebar + deep emerald primary + muted gold for the profit KPI/chart line, sharper corners (10px cards/6px inputs vs Modern Blue's 16px/10px) and bolder headlines (w800 vs w700) — a deliberately more formal, enterprise-financial look. `themeVariantProvider` (same in-memory-only pattern as the existing `localeProvider` — not yet persisted across restarts) drives `MaterialApp.router`'s `theme`/`darkTheme`; a new "Appearance" section in Settings (`AppearanceSection`, mirroring `LanguageSection`'s pattern) lets the user pick either, with a live two-color swatch preview per option. Defaults to `modernBlue`, so nothing changes for anyone who doesn't open Settings.

**Reasoning:** The 6 call sites that referenced `AppColors.incomeGreen` etc. directly (dashboard KPI cards, the shared trend chart, the Reports screen's legend) would have kept showing Modern Blue's colors even after switching variants if left as plain static constants — `ThemeExtension` is the idiomatic Flutter mechanism for exactly this ("a themeable value with no built-in `ThemeData` field"), and it's a lookup (`AppBrandColors.of(context)`), not a new state-management layer.

**Status:** Confirmed by static verification — `flutter analyze` clean, all 67 Flutter tests pass (including `widget_test.dart`, which boots the app through `themeVariantProvider`, and `reports_screen_test.dart`, which exercises the now-dynamic `TrendLegend`/chart colors). Not yet confirmed by an actual live browser click-through of the Appearance selector — do that before calling this fully verified.

---

## 2026-11-05 — D051: Dashboard gains Land Records and Team widgets, no new backend endpoints

**Context:** Request that the dashboard show "all details" (tamam details) — at the time it had KPIs, Recent Transactions, Notifications, Goat Farm, and (owners/admins) Backup Status, but nothing summarizing Land Records or who has access to the workspace.

**Decision:** Two new cards, same style as the existing `GoatFarmCard`: `LandRecordsCard` (parcel count, owned/leased breakdown, net P&L from the existing `reports/profitability` endpoint, upcoming lease expirations within 60 days) and `TeamSummaryCard` (active-member count by role, from the Staff tab's own `GET /workspaces/:id/members`, linking to `/staff`). Both reuse existing endpoints — `land.controller.ts`'s list/profitability routes have no role restriction beyond workspace membership, so `LandRecordsCard` is shown to every member, same as `GoatFarmCard`; `TeamSummaryCard` likewise.

**Reasoning:** No new backend work needed — every figure on both cards was already served by an existing endpoint for its own screen (Land Records, Staff tab); the dashboard just surfaces a summary of each, matching the pattern already established by `GoatFarmCard`/`BackupStatusCard`. Kept strictly to real data per the project's standing no-mock-data rule (DECISIONS.md D043) — no placeholder figures while a provider loads (loading/error states shown instead).

**Status:** Confirmed by static verification — `flutter analyze` clean, all 67 Flutter tests pass. Not yet confirmed by an actual live browser view of a workspace with land parcels and multiple staff members — do that before calling this fully verified.
