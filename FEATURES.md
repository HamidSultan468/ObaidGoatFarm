# Features

Feature inventory by module, with build status. This is the practical, user-facing companion to [REQUIREMENTS.md](REQUIREMENTS.md) (which states requirements) and [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) (which tracks verification). Status tags: ✅ built & working · 🟡 partial · ⬜ planned, not built.

## Authentication & Account
- ✅ Register with email + password
- ✅ Log in / log out
- ✅ Session persists across app restarts (secure token storage + auto-refresh)
- ✅ Multi-factor authentication (TOTP) — enroll (QR + manual secret), confirm, disable-with-proof, step-up login challenge
- ✅ Device/session management — view active sessions, revoke one (see DECISIONS.md D013 for the current scope boundary)
- ⬜ Forgot/reset password
- ⬜ Change email / change password from settings

## Workspaces (multi-tenant)
- ✅ Create a workspace — backend + real Flutter screen (`CreateWorkspaceScreen`), shown automatically to an authenticated user with none
- ✅ Invite a member to a workspace — backend + a real "Invite member" Quick Action on the dashboard (email + role)
- 🟡 List workspaces — backend returns the full list; the app auto-selects the first one, no switcher UI yet
- ✅ Per-workspace role management — `WorkspaceRole` enforced server-side via `WorkspaceGuard` + `RolesGuard`

## Super Admin Console (platform-level, separate from workspaces)
- ✅ View all workspaces / all users platform-wide
- ✅ Activate/deactivate a workspace or user — Super Admin Owner + MFA required
- ✅ Reassign a user's platform role (ADMIN ↔ USER) — Super Admin Owner + MFA required
- ⬜ Feature flags, client licensing, API/provider settings, theme management, system-log viewer — see [ADMIN_CONSOLE.md](ADMIN_CONSOLE.md)

## Dashboard
- ✅ KPI summary cards (Income / Expenses / Profit / Bank Balance) — **now real**, computed from the Phase 05 accounting engine (Profit & Loss + liquid-balance reports), not a zero state
- ✅ Sidebar navigation to every module, responsive (drawer on narrow widths)
- ✅ Global search — real results from sidebar destinations + the caller's workspaces (nothing else exists to search yet)
- ✅ Quick Actions panel — one real action today (Invite Member); the mockup's other actions (New Receipt, Scan Receipt, etc.) aren't shown since those modules don't exist, rather than being dead buttons
- ✅ Recent Transactions feed — real, from the accounting engine
- ⬜ Financial trend chart — data is real and queryable; no charting library wired in yet
- ⬜ Notification preview panel

## Financial Management (Phase 05)
- ✅ Chart of accounts — default accounts seeded per workspace, custom accounts, balance + statement views, deactivate (not delete)
- ✅ Record income / expense / transfer — guided forms that post a correct double-entry transaction without the user handling debits/credits directly
- ✅ Customer & supplier contacts, with a per-contact ledger (every entry tagged to them)
- ✅ Reports — Profit & Loss (now powers the real dashboard KPIs), trial balance, simplified cash flow, liquid (bank) balance
- ✅ Budgets — set an amount per account/period, check progress against actual activity
- ✅ Recurring transaction templates — manual "run now" trigger (no unattended scheduler yet)
- ✅ Approval workflow — entries above a workspace-set threshold require OWNER/ADMIN approval before posting
- ✅ Reversal — the only way to correct a posted entry; posted entries are otherwise immutable
- ✅ QR-verified receipts — a public, minimal-disclosure verification endpoint for a receipt's authenticity
- 🟡 Invoices as a first-class document — not built yet (Income/Expense/Transfer/Manual cover the common cases today)
- See [ACCOUNTING.md](ACCOUNTING.md) for the full module overview and known simplifications

## Goat Farm Management (Phase 06)
- ✅ Animal profiles with pedigree, offspring, ownership, dietary notes; sold/deceased lifecycle
- ✅ Health & vet records with next-due dates; weight history
- ✅ Breeding: mating → pregnancy → kidding (kids registered automatically); 150-day expected kidding
- ✅ Farm schedule (due/overdue health tasks, expected kiddings) on the Goat Farm screen and dashboard
- ✅ Per-animal income/expense/net from tagged transactions
- ⬜ Feed inventory, push reminders, templates, WhatsApp entry — see [GOAT_FARM.md](GOAT_FARM.md)

## Land Management (Phase 07)
- ✅ Parcels with khasra number, tenure, leases, owner, land use, status
- ✅ Kanal / marla / acre / sq ft / sq m / hectare conversions (marla = 272.25 sq ft)
- ✅ Per-parcel profitability and an all-land report
- ⬜ Maps, purchase/sale/lease templates — see [LAND_MANAGEMENT.md](LAND_MANAGEMENT.md)

## Documents & Records (Phase 08)
- ✅ Encrypted photo/PDF attachments on animals, land, transactions, contacts, or general
- ✅ My Records library with module filter and search
- ✅ Universal "Add new" menu
- ⬜ OCR, voice-to-record drafts, templates, exports — see [DOCUMENTS_MEDIA.md](DOCUMENTS_MEDIA.md)

## Notifications (Phase 09)
- ✅ Bell with unread badge, preview panel, Notifications screen
- ✅ Automatic reminders (animal health, kidding, lease end, approvals) with owner-chosen recipients
- ✅ Manual messages (owner/admin) and platform announcements (Super Admin Owner)
- ✅ Per-user in-app/email choices and quiet hours; email via SMTP with retries
- ⬜ Push notifications — see [NOTIFICATIONS.md](NOTIFICATIONS.md)

## Backup (Phase 10)
- ✅ Encrypted manual and daily backups, verify, download, delete, dashboard card
- ✅ Restore into a new workspace (from a stored backup or a downloaded file); workspace switcher
- ⬜ Google Drive / OneDrive / Dropbox / S3 — see [BACKUP_STORAGE.md](BACKUP_STORAGE.md)

## AI & WhatsApp (Phase 11)
- ✅ AI Assistant: text (English/Urdu/Roman Urdu) or receipt → draft → review → approve
- ✅ AI keys per workspace (encrypted), failover, monthly limits, usage
- ✅ WhatsApp: link your phone, send a message, get a draft to approve
- ⬜ Voice notes; live use needs your API key / WhatsApp Business number — see [AI_AUTOMATION.md](AI_AUTOMATION.md), [WHATSAPP_INTEGRATION.md](WHATSAPP_INTEGRATION.md)

## Reporting & Analytics (Phase 12)
- ✅ 8 cross-module reports: financial summary (with a monthly income/expense/net trend chart), balance sheet, trial balance, farm performance, animal growth (ADG), land income & expenses, audit log, operations — one generic report model/renderer covers all of them, so a new report needs no new UI
- ✅ Role-gated per report (finance/farm/audit viewers) — the report picker only ever offers what the signed-in member may open, server-enforced
- ✅ CSV / Excel (hand-written OOXML, no vulnerable dependency) / PDF export, identical figures to the on-screen table, downloaded through the browser's save dialog
- ✅ Date-range, "as of," or no date filter depending on the report; exports always match what's on screen
- ⬜ Saved/scheduled reports, a dedicated chart per report beyond the financial summary's trend — see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)

## Offline Mode (Phase 13)
- ✅ Write-outbox for income/expense/transfer/animal weight/health: queued encrypted when offline, auto-retried on reconnect with the same idempotency key (never double-posts), manual retry/discard from a sync-status panel
- ✅ Optimistic concurrency (`If-Match`/412) on animal and land parcel edits — a stale edit is refused, never silently overwritten
- 🟡 Deliberately a write queue, not an offline read cache — see [OFFLINE_SYNC.md](OFFLINE_SYNC.md) for scope

## Localization
- ✅ English/Urdu language switcher in Settings — genuinely changes the running app's locale, not just a translated-but-inert control
- ✅ Core screens translated: login (including the MFA challenge step), sidebar navigation, dashboard title, settings section headers, workspace creation
- ✅ RTL verified by an automated test (`app/test/l10n_test.dart`) — Urdu renders with `TextDirection.rtl`
- 🟡 Deeper copy still English-only: dialog bodies (MFA/Admin screens), backend-sourced error messages, module-placeholder subtext — see DECISIONS.md D014 for the exact boundary
