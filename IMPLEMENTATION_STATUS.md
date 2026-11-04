# Implementation Status

Last updated: 2026-11-05

This document tracks what is actually built and verified, as distinct from what is planned. Per CLAUDE.md §5/§13: nothing is marked done here until it has been run/tested, and unverified work is explicitly called out as such. Tracked against the 6-phase plan in [PHASES.md](PHASES.md); CLAUDE.md's original phase numbers are kept as sub-headings since that's the detailed scope definition.

## Legend
- ✅ Done — implemented and verified (ran/tested successfully)
- 🟡 In progress — code written, not yet fully verified
- ⬜ Not started
- 🔴 Blocked — see note

## Phase 1 — Foundation & Core Platform: ✅ verified live (open items listed below)

### CLAUDE.md Phase 01 — Project Audit
- ✅ Repository inspected: was an empty documentation scaffold, no code, no git history.
- ✅ Git repository initialized, pushed to `https://github.com/HamidSultan468/ObaidGoatFarm`.
- ✅ Stack decisions recorded — see [DECISIONS.md](DECISIONS.md) (21 decisions logged to date).

### CLAUDE.md Phase 02 — System Foundation
- ✅ Backend: NestJS 12 + TypeScript 6, ESM, Vitest. Prisma 7 + `@prisma/adapter-pg` (driver-adapter config — Prisma 7 removed the old `datasource.url` schema syntax, DECISIONS.md D008).
- ✅ Config validation at boot (`DATABASE_URL`, `ENCRYPTION_KEY`, JWT secrets) — fails fast rather than running half-configured.
- ✅ Global error handling, security middleware (`helmet`, CORS allowlist, rate limiting, `ValidationPipe`), audit logging (`AuditInterceptor`).
- ✅ `Money` value object (`decimal.js`-backed) — **9/9 unit tests passing**.
- ✅ `EncryptionService` (AES-256-GCM, Node's built-in `crypto`) for secrets-at-rest (DECISIONS.md D011).
- ✅ Whole-backend type-check (`tsc --noEmit`): **passing, 0 errors** — re-verified after every module added (auth, MFA, workspaces, admin).
- ✅ Flutter client scaffolded for Android/iOS/Web/Windows. Flutter SDK installed via the no-admin manual method (DECISIONS.md D007) since Chocolatey needed elevation unavailable here.
- ✅ `flutter analyze`: **0 issues**. `flutter test`: **2/2 passing** (login-screen boot test + an automated Urdu/RTL rendering test).
- ✅ **Live UI verification**: ran the actual app in Chrome (`flutter run -d chrome`) and confirmed via screenshot that the login screen renders correctly at both wide and narrow (480px) widths — the Windows desktop target is blocked on enabling Developer Mode, a system security setting only you can approve (see "Blockers").
- ✅ **Database live**: PostgreSQL is now running locally; `prisma migrate dev --name init` created the `tangent_smart_manager` database and applied migration `20261104051734_init` — the database is in sync with the schema. `GET /health` returns `{"status":"ok","database":"connected"}`.
- ⬜ CI pipeline, linting-on-commit hooks.

### CLAUDE.md Phase 03 — Authentication & Administration
- ✅ Auth: register, login, refresh (rotating hashed tokens), logout, `GET /auth/me` for session restore.
- ✅ **MFA (TOTP)**: enroll (`/auth/mfa/setup` → `verify-setup`), disable-with-proof, step-up login challenge (`mfaRequired`/`mfaToken` → `/auth/mfa/login`) — DECISIONS.md D010/D012.
- ✅ **Session/device management**: `GET /auth/sessions`, `DELETE /auth/sessions/:id` — real data (active refresh tokens), not a stub; friendly device metadata is a tracked follow-up (DECISIONS.md D013).
- ✅ `WorkspaceGuard` (tenant isolation) + `RolesGuard` (per-workspace RBAC) + `GlobalRolesGuard` (platform RBAC) + `MfaRequiredGuard` (owner-operation MFA gate).
- ✅ **Bug found and fixed**: `RolesGuard` was initially registered as a global guard, which would have run it before the route-level `WorkspaceGuard` populated the membership it checks — every role-gated route would have rejected unconditionally. Fixed by making it route-level only, always paired with `WorkspaceGuard`. Caught while building the first real consumer of the combination (see SECURITY.md).
- ✅ Workspace module: create (caller becomes `OWNER`), list mine, get one (tenant-guarded), invite a member (`OWNER`/`ADMIN` only).
- ✅ **Super Admin Console**: list all workspaces/users, activate/deactivate either, reassign a user's platform role — all mutations require `SUPER_ADMIN_OWNER` **and** MFA enabled, satisfying CLAUDE.md's "protect critical owner operations with MFA" as an actual access gate, not just a logging note.
- ✅ Type-checks clean through every addition above.
- ✅ **Verified end-to-end against the live database** (see "Live end-to-end verification" below): register, login, workspace creation, and tenant isolation (a non-member gets `403` on another workspace's data). MFA, session revoke, and the admin console mutations are not yet exercised live.
- ⬜ Feature flags, client licensing, API/provider settings, theme management, system-log viewer (rest of the Admin Console scope — see [ADMIN_CONSOLE.md](ADMIN_CONSOLE.md)).
- ⬜ Identity document storage.

### CLAUDE.md Phase 04 — Dashboard & UI
- ✅ Flutter app wired end-to-end: `main.dart` → Riverpod → `go_router` (auth- and workspace-aware redirects, including an MFA challenge state and an admin-only route guard) → login → dashboard shell.
- ✅ Theme matching the approved reference image: navy sidebar, "Modern Blue" accent, semantic KPI colors, light + dark mode.
- ✅ Login screen, now with an MFA code-entry step when the account requires it.
- ✅ Session persistence via `flutter_secure_storage` (behind a `TokenStorage` abstraction for testability), automatic 401 → refresh → retry.
- ✅ Dashboard shell: sidebar (all 12 module items + conditional Admin Console entry), top bar, KPI row, module cards.
- ✅ **Real Global Search** — searches sidebar destinations and the caller's workspaces, navigates/selects on tap.
- ✅ **Real Quick Action** — Invite Member, calling the actual workspace-invite endpoint.
- ✅ **Responsive layout** — sidebar becomes a drawer below 900px width; verified live via a resized Chrome window screenshot (not just assumed from the breakpoint code).
- ✅ **Honest data policy maintained throughout**: KPI cards and Recent Transactions now show genuine Phase 05 data instead of a zero state; sections still genuinely unbuilt (Financial Overview *chart*, Goat Farm, Cloud Backup) show an explicit "not built yet, planned for Phase X" card; unbuilt sidebar destinations route to a real, honest placeholder screen.
- ✅ Workspace flow: `CreateWorkspaceScreen` shown automatically when none exist; dashboard shows the real selected workspace name.
- ✅ **Settings screen** (new): account info, MFA management (QR setup, enable, disable), active sessions (list, revoke), language switcher.
- ✅ **Admin Console screen** (new): Workspaces/Users tabs, toggle active status, visible only to platform admins, with a server-enforced redirect for anyone else who navigates to `/admin` directly.
- ✅ **Localization**: working English/Urdu switcher (`flutter gen-l10n`, real ARB translations), core screens translated (login incl. MFA step, sidebar, dashboard title, settings, workspace creation). RTL verified by an automated test (`app/test/l10n_test.dart`) — not just assumed from `supportedLocales`.
- ✅ **Run end-to-end in a real browser against the live backend and database**: logged in through the actual login form, landed on the authenticated dashboard for the real workspace, and navigated to Bank & Accounts — all verified by screenshot. This live run found and fixed three real bugs that static checks had missed (see "Live end-to-end verification").
- ✅ Multi-workspace switcher in the top bar (built in Phase 4; `GET /workspaces` now includes the caller's `myRole`).
- ⬜ Financial trend chart, notification preview panel (need a charting library / Phase 09 respectively — Recent Transactions is now real, see Phase 2 below).
- 🟡 Deeper UI copy (dialog bodies, backend error messages, placeholder subtext) remains English-only — see DECISIONS.md D014 for the exact boundary.

## Phase 2 — Financial Management Core: ✅ core verified live (open items listed below)

Full detail in [ACCOUNTING.md](ACCOUNTING.md); this is the summary.

- ✅ **Ledger engine** (`backend/src/modules/accounting/ledger/`): `LedgerService.postEntry()` is the single write path for every financial record; balance validation (`assertBalanced`) is pure, DB-free, and unit-tested — **6/6 tests passing**, including a proof that `0.10 + 0.20 - 0.30` balances exactly where native float arithmetic wouldn't.
- ✅ **Reversal & approvals**: `reverseEntry` is the only correction path for a posted entry (no update/delete); an optional per-workspace `approvalThreshold` routes large entries to `PENDING_APPROVAL` until an OWNER/ADMIN approves or rejects.
- ✅ **Chart of accounts**: a default chart (Cash, Bank, Accounts Receivable, Accounts Payable, Owner's Equity, Sales Income, General Expense) is seeded automatically on workspace creation; custom accounts, per-account balance, and a full chronological statement (doubling as a cashbook/bank statement view).
- ✅ **Guided transactions**: Record Income / Expense / Transfer endpoints construct correct double-entry postings without the caller handling debits/credits; a generic manual-entry endpoint covers everything else.
- ✅ **Customer & supplier ledgers**: a `Contact` has no parallel bookkeeping — its ledger is simply its tagged journal entries, with a running total.
- ✅ **Reports**: Profit & Loss, trial balance, a simplified cash flow (net CASH/BANK movement — DECISIONS.md D018), and a liquid-balance endpoint.
- ✅ **Budgets**: amount per account/period, compared against actual posted activity on request.
- ✅ **Recurring templates**: schema + manual "run now" trigger; no unattended scheduler exists in this environment yet (DECISIONS.md D017).
- ✅ **QR-verified receipts**: a public, minimal-disclosure verification endpoint (DECISIONS.md D019).
- ✅ **Dashboard is now wired to real data**: Total Income / Total Expenses / Net Profit (from Profit & Loss) and Bank Balance (from liquid-balance) replace the Phase 1 zero-state; Recent Transactions shows real entries.
- ✅ Whole-backend type-check clean through every file in this module (verified after the full module, not just incrementally).
- ✅ Flutter: Accounts (chart of accounts + record income/expense/transfer + account statement sheet), Contacts (Customers & Suppliers), and Reports (Profit & Loss) screens built and wired into the sidebar/router. `flutter analyze`: 0 issues. Existing tests (2/2) still passing.
- ✅ **Verified end-to-end against the live database** (see below): default chart of accounts seeded on workspace creation; income and expense posting; balances, P&L, trial balance (balanced), and liquid balance all exactly correct; reversal restores balances and a second reversal is rejected; an unbalanced manual entry is rejected with the exact imbalance; the public receipt endpoint works without auth and returns only the documented fields. Budgets, recurring templates, approvals, and contacts are type-checked but not yet exercised live.
- ✅ Flutter widget tests for the Record Transaction dialog (3 tests, fake repository): correct API call with chosen accounts/amount, validation blocks an empty submit, and the expense category list offers only EXPENSE accounts.
- ✅ **Security fix (found while building Phase 3):** `LedgerService.postEntry` did not check that the accounts and contact an entry references belong to the entry's workspace — a member of one workspace could post against another tenant's account by id. Every referenced account (must also be active), contact, animal and land parcel is now ownership-checked before posting (DECISIONS.md D024); verified live (`400` for a foreign account/animal/parcel).
- ✅ **Validation fix:** the global `ValidationPipe` silently converted a JSON number into a string, so a float like `100.5` passed the "amount must be a decimal string" check. Implicit conversion is now off (DECISIONS.md D022); verified live (`400` for a numeric amount).
- ✅ Income/Expense can be tagged with an animal and/or a land parcel (`animalId`, `landParcelId`); reversals keep the tags so a reversed cost drops out of per-animal/per-parcel profit automatically.
- ⬜ Invoices as a first-class document (Income/Expense/Transfer/Manual cover current scope).
- ⬜ Reconciliation matching UI (`JournalLine.reconciledAt` exists in the schema; nothing sets it yet).
- ⬜ Trial balance / cash flow Flutter screens (available via the API; only Profit & Loss has a dedicated screen so far).
- ⬜ Budgets and Recurring Templates Flutter screens (backend complete; no UI yet).

## Phase 3 — Domain Modules: 🟡 core built and verified live; AI-dependent and template items open

Migration `20261104120000_phase3_farm_land_documents` applied (generated with `prisma migrate diff` + `migrate deploy`, since `migrate dev` refuses non-interactive shells — DECISIONS.md D026).

### CLAUDE.md Phase 06 — Goat Farm Management ([GOAT_FARM.md](GOAT_FARM.md))
- ✅ Animal profiles: unique tag per workspace, name, species, breed, sex, birth date, color, acquisition (purchased/born/gifted) and date, ownership (share farming), sire/dam pedigree (sex-checked, same workspace, never self), dietary restrictions, notes.
- ✅ Lifecycle separate from health: ACTIVE → SOLD/DECEASED is one-way with date and reason; history is never deleted. Health status (healthy/sick/under treatment/quarantined) changeable from the profile.
- ✅ Health & vet records (vaccination, deworming, checkup, illness, treatment, medication, injury) with medicine, dosage, vet, and a next-due date.
- ✅ Weight records stored as exact decimals (never float).
- ✅ Breeding: mating (natural/AI, farm or outside sire) → pregnant / not pregnant / aborted → kidding. Expected kidding defaults to mating + 150 days. One open record per doe. Recording a kidding registers each live kid as a new animal (dam/sire/breed inherited, BORN_ON_FARM) in one transaction — a tag clash writes nothing.
- ✅ Farm overview + 30-day schedule: herd counts, pregnant count, health follow-ups due/overdue (a follow-up drops off once a newer record of the same type exists), expected kiddings. Shown on the dashboard (FR-4.6) and the Goat Farm Schedule tab.
- ✅ Per-animal finances: income/expense/net from ledger entries tagged with the animal.
- ✅ Flutter: Goat Farm screen (Herd with search + status filter, Breeding, Schedule), animal detail (profile, pedigree links, offspring, weights, health, finances, documents), dialogs for add animal / health / weight / exit / mating / kidding.
- ⬜ Editing a full animal profile from the UI (API `PATCH` exists; the UI changes health status only).
- ⬜ Feed inventory/rations (feed *costs* are recorded as expenses tagged with an animal), push reminders (Phase 09), record templates, WhatsApp commands (Phase 11).

### CLAUDE.md Phase 07 — Land Management ([LAND_MANAGEMENT.md](LAND_MANAGEMENT.md))
- ✅ Land parcels: name, location, khasra/survey number, owner, land use, tenure (owned / leased in / leased out / rented out), status (active / lease ended / sold), lease counterparty (a Contact, workspace-checked), lease dates (end ≥ start) and terms.
- ✅ Area in kanal, marla, acre, sq ft, sq m, hectare — stored canonically in sq ft as Decimal next to the entered unit; every response carries all conversions and an "acre kanal marla" breakdown. Marla = 272.25 sq ft (revenue standard, DECISIONS.md D023). Unit-tested; `GET /land/convert` calculator.
- ✅ Per-parcel income/expense/net and a profitability report across all parcels (optional date range).
- ✅ Flutter: Land Records list (with per-parcel net and all-land totals), parcel detail (details, lease, area conversions, finances, documents), Add land dialog.
- ⬜ Maps, purchase/sale/lease templates, editing a parcel from the UI (API `PATCH` exists; the UI changes status only).

### CLAUDE.md Phase 08 — Documents & Records ([DOCUMENTS_MEDIA.md](DOCUMENTS_MEDIA.md))
- ✅ Attachments on animals, land parcels, transactions, contacts, or as general documents. The owning record must exist in the same workspace.
- ✅ Files are AES-256-GCM encrypted on disk under `STORAGE_DIR` (verified: no plaintext bytes on disk); SHA-256 integrity check on every download; storage keys never leave the server.
- ✅ Type detected from the file's bytes (JPEG/PNG/WEBP/PDF only) — a renamed executable or an SVG is rejected; 10 MB limit (`413`); filenames stripped of paths/control characters; downloads sent `no-store` + `nosniff` with RFC 6266 filenames (Urdu names preserved).
- ✅ Flutter: Photos & documents card on animal and land pages (upload / view image / download / delete), My Records library (all modules, filter, search), universal **Add new** menu in the top bar (income, expense, animal, mating, land, contact, document).
- ⬜ OCR and voice-to-record drafts (depend on the AI integration, Phase 11), templates, exports.

### Verification (2026-11-04)
- Backend: `tsc` 0 errors; **44/44** unit tests (new: profitability ×5, gestation/transitions ×6, area conversion ×6, file-type/filename ×7, encryption ×5).
- Flutter: `flutter analyze` 0 issues; **33/33** tests (new: farm formatting ×10, farm dialogs ×5, land/documents ×5). A widget test caught a real overflow in the Record Transaction dialog once the tag pickers were added — fixed by making the form scroll.
- Live API E2E against PostgreSQL: **70/70** scripted checks (Goat Farm 40, Land + Documents 30), including every validation and tenant-isolation case above.
- Live UI in Chrome (driven through the DevTools protocol with real clicks/typing): dashboard Goat Farm card, herd list, animal detail, breeding tab, Add animal dialog → new animal appears, Land list and parcel detail with an encrypted PDF attached, My Records, Add new menu, Income dialog with animal/land pickers.
- 🟡 New Phase 3 screens are English-only so far (same boundary as Phase 2 screens — DECISIONS.md D014); Urdu strings still to be added.

## Phase 4 — Engagement & Automation: 🟡 built and verified live; items needing outside accounts open

Migrations `20261104160000_phase4_notifications`, `20261104170000_phase4_backups`, `20261104180000_phase4_ai_drafts`, `20261104190000_phase4_whatsapp` applied (no drops).

### CLAUDE.md Phase 09 — Notifications ([NOTIFICATIONS.md](NOTIFICATIONS.md))
- ✅ In-app inbox per user: bell with unread badge (refreshes every 60 s) and preview panel, Notifications screen (all/unread, mark read, mark all read), links open the related record.
- ✅ Automatic rules every 10 minutes (in-process scheduler): animal health due within 3 days / overdue, kidding within 7 days / overdue, lease ending within 30 days / ended, transactions awaiting approval. A `dedupeKey` per user means each reminder arrives once; an overdue item escalates once as WARNING.
- ✅ Owner/admin control of each rule (on/off, recipient roles), "check now", delivery log.
- ✅ Manual sending: workspace owner/admin to roles or chosen members; platform announcements by the Super Admin Owner (MFA required).
- ✅ Per-user preferences per category (in-app / email) and quiet hours in the user's time zone.
- ✅ Email via SMTP with retries (1, 5, 15, 60 min; 5 attempts) and a delivery log. Verified against a local SMTP server: real messages sent, quiet hours defer, a rejected recipient is retried. Email stays off until `SMTP_*` is configured.
- ⬜ Push notifications (needs a Firebase project / Apple push setup — your accounts).

### CLAUDE.md Phase 10 — Backup & Restore ([BACKUP_STORAGE.md](BACKUP_STORAGE.md))
- ✅ Encrypted backups of a whole workspace (all records and documents) — gzip + AES-256-GCM with a key derived from the server key (HKDF). Manual, plus automatic daily at 02:00 keeping the newest N (default 7); manual backups never pruned automatically.
- ✅ Verification before any restore: tamper check, checksum, format version, every reference, every journal entry balances.
- ✅ Restore always into a **new** workspace (new ids, every link remapped, one transaction, files re-encrypted); the original is never touched. Restore from a stored backup (owner) or an uploaded `.tsmbak` (owner of the source workspace or the Super Admin Owner only).
- ✅ Download, delete, status (last backup, failures, storage used), dashboard Backup card, failure notifications (CRITICAL).
- ✅ Workspace switcher in the top bar (needed to open a restored workspace; also closes the Phase 1 open item).
- ⬜ Google Drive / OneDrive / Dropbox / S3 adapters (need OAuth apps / credentials — your accounts). The storage interface is in place; today backups are stored on this server's disk.

### CLAUDE.md Phase 11 — AI & WhatsApp ([AI_AUTOMATION.md](AI_AUTOMATION.md), [WHATSAPP_INTEGRATION.md](WHATSAPP_INTEGRATION.md))
- ✅ AI provider settings per workspace (owner/admin): Anthropic API keys stored encrypted (only a 4-character hint is ever shown), model choice, priority order for failover, monthly request limit, connection test, monthly usage.
- ✅ AI Assistant screen: type what happened (English / Urdu / Roman Urdu) or read a receipt photo/PDF → a **draft**. Claude via the official SDK with structured JSON output; every id the model returns is checked against the workspace's real records before it can appear in a draft.
- ✅ Draft review: edit fields, approve or reject. Approval runs the same validated services as manual entry (ledger balancing, approval threshold, tenant checks) and is claimed atomically, so double or simultaneous approvals post once.
- ✅ WhatsApp Business Cloud API: signed webhook (HMAC over the raw body), phone linking with a one-time code (hashed, 15 min, 5 attempts), linked users' messages become drafts, retried webhooks processed once, replies via the Graph API, message log.
- 🟡 **Not verified with a real AI key or a real WhatsApp number** — none were available. Verified instead: real calls to Anthropic and to the Graph API with invalid credentials (typed errors handled, failover, logging), the whole draft-approval path with test drafts, and the signed-webhook flow with requests built exactly like Meta's.
- ⬜ Voice notes (need a speech-to-text provider), other AI vendors (adapter interface ready), AI summaries.

### Verification (2026-11-04)
- Backend: `tsc` 0 errors; **76/76** unit tests (new: delivery timing ×5, backup cipher/format ×8, AI extraction ×10, WhatsApp ×7).
- Flutter: `flutter analyze` 0 issues; **52/52** tests (new: notifications ×6, backup ×3, API errors ×4, draft review ×3, AI/WhatsApp models ×3).
- Live API E2E against PostgreSQL: **122 new checks** — notifications 31, backup 36, AI + drafts 27, WhatsApp 28 — plus the earlier suites re-run (farm 40, land/documents 30): **192/192**.
- Live UI in Chrome (DevTools protocol): bell badge and panel, inbox, automatic rules, Settings notification preferences, workspace switcher, dashboard backup card, Settings backup (Back up now, Verify), AI Assistant ("not set up" message; a WhatsApp draft edited and approved → posted journal entry 18,000.00), AI and WhatsApp settings.
- `npm audit --omit=dev`: 0 vulnerabilities.

### Bugs found and fixed during Phase 4
1. **Launcher served an old app after rebuilds** — `max-age=3600` on non-hashed `main.dart.js`. Now `no-cache` + ETag (304 when unchanged) (DECISIONS.md D034).
2. **Field errors never reached the client** — the error filter dropped a service's `errors` list; and for validation failures the Flutter app showed "Bad Request Exception". Both fixed: `details` carries field errors, the app shows them (D033).
3. A schema patch aborted mid-way and an empty migration got recorded; the no-op history row was removed and the migration regenerated (no database change had occurred).

## Phase 5 — Analytics & Resilience: ✅ verified live

### CLAUDE.md Phase 12 — Reporting & Analytics
- ✅ A single presentation-neutral report model (`ReportDocument`/`ReportSection`/`ReportColumn`, backend `report-table.ts`, mirrored exactly by Flutter's `analytics_models.dart`) drives 8 reports through one renderer and one set of exporters — a new report needs no new UI, only a new entry in `REPORT_ACCESS`/`reportLabels`.
- ✅ Reports: financial summary (with a monthly income/expense/net trend), balance sheet (as-of date, accounting equation check), trial balance, farm performance (herd movement, kidding/survival stats, optional profit-by-animal), animal growth (ADG from weight records), land income & expenses, audit log, operations.
- ✅ Role-gated per report server-side (`FINANCE_VIEWERS`/`FARM_REPORT_VIEWERS`/`AUDIT_VIEWERS`) — `GET /workspaces/:id/analytics` returns only what the caller's role may open, and the Flutter report picker is built from that list, not a hardcoded menu.
- ✅ Exports: CSV (UTF-8 BOM, formula-injection-safe quoting), Excel (hand-written OOXML via Node's built-in `zlib` — `exceljs` was removed after it pulled in vulnerable transitive dependencies; DECISIONS.md), PDF (`pdfkit`, repeated headers and page numbers on multi-page tables). All three always show the exact same figures as the on-screen table.
- ✅ Pakistan-calendar-day (`Asia/Karachi`) date ranges, not UTC — a transaction made late at night in Pakistan now falls in the correct day's report.
- ✅ Flutter: Reports & Analytics screen rebuilt from a single Profit & Loss card into the full generic report viewer — report picker (role-filtered), date/as-of filters, CSV/Excel/PDF export buttons (`file_picker`'s `saveFile`), a generic table renderer for every section (with a bolded totals row), and an `fl_chart` trend line for the financial summary.
- ⬜ Saved/scheduled reports; a dedicated chart beyond the financial summary's trend.

### CLAUDE.md Phase 13 — Offline Mode & Synchronization
- ✅ **Idempotency keys**: any `POST` with an `Idempotency-Key` header is deduplicated server-side for 7 days (same key + same body → replayed response, not reposted; same key + different body → `422`; 5 simultaneous submissions with one key → exactly one entry).
- ✅ **Optimistic concurrency**: `Animal.update()`/`LandParcel.update()` accept `If-Match`; a stale edit is refused `412` and never applied.
- ✅ **Flutter write-outbox** (`core/offline/`): income/expense/transfer/animal-weight/animal-health writes go through `OutboxController`, which attempts immediately, queues (encrypted, `flutter_secure_storage`) on a dropped connection, and retries automatically on the offline→online edge — always replaying with the same idempotency key, so a retry never double-posts. A top-bar sync indicator and a pending-items sheet (retry/discard) make queued state visible, never silent.
- ✅ Deliberately a write queue, not an offline read cache (see [OFFLINE_SYNC.md](OFFLINE_SYNC.md) "Scope") — satisfies "never silently overwrite a posted financial record" by construction: posted entries are already immutable (reversal-only), and the outbox never queues edits, only new writes.
- ⬜ Background sync while the app is closed (retry triggers on app-foreground connectivity changes and manual retry only).

### Verification (2026-11-04)
- Backend: `tsc` 0 errors; **98/98** unit tests (new: report math/rounding ×12, idempotency ×10). `npm audit --omit=dev`: 0 vulnerabilities (after replacing `exceljs` with the hand-written OOXML writer).
- Flutter: `flutter analyze` 0 issues; **63/63** tests (new: offline outbox controller ×9, Reports screen ×2).
- Live API E2E against PostgreSQL (`backend/scripts/e2e/reports-sync.e2e.mjs`): **37/37** — per-role report access and 403s, validation, financial-summary/balance-sheet/trial-balance exactness, CSV/Excel/PDF export correctness (cross-checked independently with Python `openpyxl` and `pymupdf`), idempotency (replay/reject/concurrent/per-user-scoping), `If-Match` conflicts on animals and land.
- Live UI in Chrome (DevTools protocol, real clicks/typing against the live backend): login → Reports & Analytics → switched reports via the picker → changed date range (confirmed live refetch in the network log, "From: 01 Jan 2026" applied correctly) → Financial Summary trend chart rendered with real multi-month data → CSV export confirmed end-to-end (server returned the exact byte count; Chrome's download manager received 100% of those bytes under the correct generated filename).

### Bugs found and fixed during Phase 5
1. **`DropdownButtonFormField` overflow on the Report picker** — caught by the new `reports_screen_test.dart` widget test (not by `flutter analyze`, which doesn't catch layout overflow), not by the live browser run (the real font metrics happened not to overflow at the tested width). Fixed with `isExpanded: true` + `Text(..., overflow: TextOverflow.ellipsis)`, the same pattern already used for the account dropdowns (Phase 2).
2. **Reports endpoints had no role restriction** — `reports.controller.ts`'s financial report endpoints predate Phase 12 and were reachable by any workspace member. Fixed by adding `RolesGuard` + `@Roles(...FINANCE_VIEWERS)`, matching the new analytics endpoints' access rule.
3. **Date ranges used UTC calendar days** — a transaction posted late at night in Pakistan could land in the wrong day's report. Fixed with `Asia/Karachi`-aware day boundaries (`zonedDayStart`/`zoneOffsetMinutes`).
4. **PDF export produced a spurious blank page** — the footer was drawn inside `pdfkit`'s bottom margin, which it treats as overflow and auto-adds a page for. Fixed by zeroing `pdf.page.margins.bottom` only while drawing the footer.
5. **A Riverpod/`package:test` teardown hang** while writing `outbox_controller_test.dart` — `addTearDown` runs in LIFO order, so closing a `StreamController` before disposing the `ProviderContainer` that subscribes to it hung forever. Fixed by registering `dispose()` first; documented in OFFLINE_SYNC.md as a reusable gotcha.
6. **A plain `StreamProvider` never updates in a bare `ProviderContainer` test** unless something watches/listens to it (the real app always has a widget doing so; a container-only test does not). Fixed by adding a no-op `container.listen(connectivityProvider, ...)` in the outbox test's `setUp()`.

## Phase 6 — Quality & Release: 🟡 Phase 14 (Security & QA) verified live; Phase 15 (Production Release) blocked on external accounts

### CLAUDE.md Phase 14 — Security & QA
- ✅ **Consolidated cross-module security sweep** (`backend/scripts/e2e/security-qa.e2e.mjs`, 60 live checks, two fresh independent tenants so nothing overlaps the other phase scripts' shared test accounts): tenant isolation on every `:workspaceId`-scoped route in the whole app (28 read endpoints + 4 write endpoints), confirmed blocked both by status code *and* by proving the blocked write never actually happened; a well-formed-but-nonexistent workspace id doesn't 500.
- ✅ **Critical finding, fixed**: the MFA challenge token worked as a full bearer token anywhere, completely bypassing the second factor — `JwtStrategy.validate()` never checked the token's `purpose` claim. Fixed and re-verified live; see DECISIONS.md D041 and SECURITY.md "Phase 14 findings".
- ✅ **Hardening gap, fixed**: `CORS_ORIGIN` silently defaulted to allow-all outside development if unset, and wasn't even in the validated env schema — inconsistent with every other required secret's fail-fast behavior. Now required and validated (DECISIONS.md D042).
- ✅ **Auth hardening, live-verified**: malformed/tampered/missing-token rejection, password policy (<12 chars rejected), duplicate email (409), refresh-token single-use rotation, logout revocation, the documented stateless-access-token behavior (keeps working until natural expiry after logout — by design, not a bug), rate limiting (429 within 110 rapid attempts).
- ✅ **Input validation / injection probes, live-verified**: SQL-injection- and script-tag-shaped strings stored and returned as inert literal text (confirms Prisma's parameterized queries, not string concatenation — and a codebase-wide grep found exactly one raw query anywhere, a hardcoded parameter-free health check); an over-length field is rejected 400, not silently truncated; an unexpected extra field is rejected (`forbidNonWhitelisted`, live-verified, not just configured); a negative amount is rejected.
- ✅ **Full regression**: every earlier phase's live E2E suite re-run clean after the fixes above — 219/224 (the 5 not passing need the separate `smtp-sink.mjs` helper for email, unrelated to this phase's changes).
- ✅ **Accessibility pass**: two icon-only buttons (login's password-visibility toggle, the shell's mobile menu button) had no screen-reader label — fixed with localized tooltips (English + Urdu, two new ARB keys each). Computed WCAG contrast for every `AppColors` pair: found and fixed the dashboard KPI cards' label text failing AA (DECISIONS.md D040); one remaining partial gap on those same four accent colors, and a question about the shared border/divider color, documented rather than changed blindly since closing them fully means touching the approved color palette.
- ✅ Backend: `tsc` 0 errors, **104/104** unit tests (new: env validation/CORS_ORIGIN ×3, JwtStrategy purpose-claim rejection ×3). `npm audit --omit=dev`: 0 vulnerabilities. Flutter: `flutter analyze` 0 issues, **63/63** tests (unchanged count — the accessibility fixes didn't need new tests, they're covered by the existing l10n/widget tests still passing).
- ⬜ An independent third-party penetration test (needs an external firm — see Phase 15 below, not something a code-level pass can do itself).

### CLAUDE.md Phase 15 — Production Release
- ✅ **What's buildable without outside access, done**: a multi-stage `backend/Dockerfile` (Prisma 7 has no native query-engine binary, so no Alpine/glibc binary-target issue to work around), a `docker-compose.yml` for a local prod-like stack (backend + PostgreSQL), and `.github/workflows/ci.yml` (three jobs: backend unit tests + type-check + audit, Flutter analyze + test, and a `backend-e2e` job that boots a real PostgreSQL service container, runs migrations, starts the actual compiled server, and runs the live E2E scripts against it).
- 🟡 **Written but not yet verified**: none of the above has actually been run — Docker isn't installed on this dev machine, and the CI workflow needs a push/PR plus three repo secrets to execute for the first time. Reviewed carefully, but "written" and "working" are different claims and this document says which is which.
- 🔴 **Blocked on external accounts** (listed in full in DEPLOYMENT.md "Blocked on external accounts"): a hosting provider, a domain + TLS, managed PostgreSQL in production, a Google Play Console account + signing keystore (Android), an Apple Developer account + a macOS build host (iOS — this is a Windows machine), and a monitoring/alerting provider. None of these can be provisioned by writing more code; they need you.

## Live end-to-end verification (2026-11-04)

PostgreSQL became available this session, which unblocked real verification for the first time.

**API, against the live database** (curl, real HTTP, real rows):

| Check | Result |
|---|---|
| Register / login | ✅ user created; JWT + refresh token issued |
| Create workspace | ✅ default chart of accounts (7 accounts) seeded automatically |
| Record income 5,000.00 (with receipt) | ✅ balanced entry posted, verification code issued |
| Cash balance / liquid balance | ✅ 5,000.0000 / 5,000.0000 |
| Trial balance | ✅ debits 5,000 = credits 5,000, `isBalanced: true` |
| Record expense 1,200.00 → P&L | ✅ income 5,000, expense 1,200, net profit 3,800 |
| Public receipt verify (no auth header) | ✅ returns only amount/memo/date/workspace name |
| Reverse the expense | ✅ new entry with flipped signs; cash back to 5,000 |
| Reverse it again | ✅ rejected `400` ("already been reversed") |
| Unbalanced manual entry (100.00 vs -99.99) | ✅ rejected `400` with exact imbalance 0.0100 |
| Non-member reads another workspace's accounts | ✅ rejected `403` (tenant isolation) |

**Real browser (Flutter web → live backend):** login through the actual form → authenticated dashboard showing real KPI values and real recent transactions → Bank & Accounts showing real balances.

**Bugs the live run found that static checks had missed — all fixed and re-verified:**
1. **CORS blocked every browser request** — dev origin allowlist didn't match Flutter's port. Fixed per DECISIONS.md D020; preflight verified.
2. **Layout overflow** on every KPI card and a 60px overflow on Recent Transactions — fixed-aspect-ratio grids replaced with fixed-height and natural-height layouts; verified no overflow live.
3. **Money display** — raw `$5000.0000` and a confusing `-5,000.00` income balance. Fixed with exact BigInt formatting and natural-balance display (D021); verified live and by unit tests.

A fourth bug was caught by the new widget tests rather than the live run: account dropdowns overflowed with long account names (fixed with `isExpanded` + ellipsis), plus a mislabeled "Received into" field on the transfer form and a redundant ternary.

**Current verification totals:** backend `tsc` 0 errors, 15/15 unit tests; Flutter `analyze` 0 issues, 12/12 tests.

## Notes for you

1. **Starting the app** — use the desktop icon (Tangent Smart Manager). It starts the backend on port 3000 and the app on 8770. The earlier stale backends on ports 3000/3001 are gone.
2. **Windows Developer Mode** — still needed for the Windows *desktop* build (Flutter plugin symlinks); adding the `file_picker` plugin printed the same warning. Web builds and tests are unaffected. Run `start ms-settings:developers` and turn it on, or keep using Web, which is fully verified.
3. **Marla size** — land conversions use 272.25 sq ft per marla (revenue standard). If any of your land is measured in 225 sq ft marla (common in housing schemes), say so and a per-workspace setting can be added (DECISIONS.md D023).
4. **Test accounts in your local database** (password `TangentTest12345`, local test data only): `owner@tangentsmart.test` (owner of "Obaid Goat Farm"), `admin@tangentsmart.test` (ADMIN there), `intruder@tangentsmart.test` (isolation tests), `superadmin@tangentsmart.test` (promoted to SUPER_ADMIN_OWNER directly in the local database for testing; MFA is switched off again after each test run). The backup tests also left several "Obaid Goat Farm (restored …)" workspaces — they are copies and can be ignored.
5. **To finish Phase 4 you'd need to provide** (each is optional; the app works without them): an Anthropic API key (Settings → AI assistant), WhatsApp Business details from Meta plus a public HTTPS address for the webhook (Settings → WhatsApp), SMTP details for email (`backend/.env`), and — for push and cloud backup — Firebase and Google/Microsoft/Dropbox developer apps.

Nothing is blocking further development.
