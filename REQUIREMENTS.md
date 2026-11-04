# Requirements

Source of truth for scope: CLAUDE.md's 15-phase master workflow (regrouped into 6 delivery phases in [PHASES.md](PHASES.md)). This document restates it as checkable functional and non-functional requirements, grouped by phase, with build status. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for verified-vs-planned detail and [ACCEPTANCE_CRITERIA.md](ACCEPTANCE_CRITERIA.md) for how each requirement is confirmed done.

Status tags: ✅ built & verified · 🟡 partially built · ⬜ not started.

## Non-functional requirements (apply to every phase)

| ID | Requirement | Status |
|---|---|---|
| NFR-1 | No floating-point arithmetic for money; all amounts are `Decimal` | ✅ (`Money`, Prisma `Decimal`) |
| NFR-2 | Posted financial records are immutable; corrections via reversal only | ✅ (`LedgerService.reverseEntry`; no update/delete path exists on a posted `JournalEntry`) |
| NFR-3 | Strict multi-tenant data isolation, enforced server-side | ✅ (`WorkspaceGuard`) |
| NFR-4 | Server-side role-based permissions, never trusted from client | ✅ (`RolesGuard` + `GlobalRolesGuard`) |
| NFR-5 | Complete audit trail for mutating actions | ✅ (`AuditInterceptor`) |
| NFR-6 | Secure authentication and session management | ✅ (bcrypt, rotating JWT refresh, TOTP MFA, session list/revoke) |
| NFR-7 | English + Urdu user-selectable interface language | 🟡 (working switcher + core screens translated and RTL-verified; deeper copy still English-only — see DECISIONS.md D014) |
| NFR-8 | Runs on Android, iOS, Web, Windows from one codebase | 🟡 (scaffolded for all four; Windows/Web verified runnable and visually confirmed from this dev machine — iOS needs macOS, Android needs `cmdline-tools`) |
| NFR-9 | No mock functionality or placeholder data in shipped UI | ✅ (enforced as a standing design rule — see `NotYetAvailableCard`/`ModulePlaceholderScreen`) |

## Phase 02 — System Foundation
- FR-2.1 Centralized backend with modular architecture ✅
- FR-2.2 Database with migration tooling ✅ (schema + tooling ready; migrations unapplied, no DB yet)
- FR-2.3 Centralized error handling and logging ✅
- FR-2.4 Reusable UI theming/component foundation ✅ (`AppTheme`, `AppColors`)
- FR-2.5 Application foundations for all four platforms 🟡

## Phase 03 — Authentication & Administration
- FR-3.1 Super Admin Owner / Admin / User roles ✅ (schema, enforcement, and a real admin console UI)
- FR-3.2 Granular role-based permissions ✅ (workspace-level); 🟡 finer-grained permissions beyond 5 fixed roles not yet needed/designed
- FR-3.3 Multi-client / multi-workspace management 🟡 (create/list/invite built, backend + Flutter, verified via static checks; no workspace *switcher* UI yet, unverified against a live database)
- FR-3.4 Per-client product licensing/activation ⬜
- FR-3.5 User profiles, identity documents, device management 🟡 (session list/revoke built and real; identity documents not started; device *metadata* — friendly names/platforms — not yet collected, see DECISIONS.md D013)
- FR-3.6 Super Admin control panel ✅ (user/workspace management core; feature flags/licensing/API settings/themes/logs not yet built — see [ADMIN_CONSOLE.md](ADMIN_CONSOLE.md))
- FR-3.7 Global feature activation/deactivation ⬜
- FR-3.8 MFA + audit logging on owner operations ✅ (TOTP MFA built; every `/admin/*` mutation requires `SUPER_ADMIN_OWNER` + MFA enabled + is audit-logged)

## Phase 04 — Dashboard & UI
- FR-4.1 Dashboard matching the approved reference design ✅
- FR-4.2 Navy sidebar + top navigation ✅, responsive (drawer below 900px width)
- FR-4.3 Financial KPI cards and charts ✅ (cards show real Phase 05 data; the Reports screen's Financial Summary now includes a real monthly income/expense/net trend chart — `fl_chart`, Phase 12)
- FR-4.4 Quick Actions, global search ✅ (real search over sidebar/workspaces; one real Quick Action — Invite Member — rather than non-functional buttons for unbuilt modules)
- FR-4.5 Notification previews, recent transactions 🟡 (recent transactions is real, from Phase 05; notification previews remain an honest placeholder — Phase 09)
- FR-4.6 Goat Farm overview widget ✅ (live counts + next tasks); backup status widget ✅ (Phase 10, owners/admins)
- FR-4.7 Responsive desktop/tablet/mobile layouts 🟡 (drawer breakpoint built and verified via live Chrome run at both wide and narrow widths; not yet tested on a real phone/tablet device)
- FR-4.8 Every visible control performs a real function ✅ (standing rule — no dead buttons; unbuilt destinations say so explicitly)

## Phase 05 — Financial Management Core
- FR-5.1 Centralized double-entry accounting engine ✅ (`LedgerService`; balance validation unit-tested, 6/6)
- FR-5.2 Income, expenses, transfers, receipts, invoices, payments 🟡 (income/expense/transfer/manual built; invoices/payments as first-class documents not yet — see [ACCOUNTING.md](ACCOUNTING.md))
- FR-5.3 Personal, household, shared, and business account types ⬜ (the chart-of-accounts model supports arbitrary accounts; this specific categorization isn't modeled yet)
- FR-5.4 Customer and supplier ledgers ✅
- FR-5.5 Cashbooks, bank accounts, account statements ✅ (an account statement filtered to a CASH/BANK account *is* the cashbook/bank-statement view)
- FR-5.6 Profit/loss, cash flow, reconciliation, financial reports 🟡 (P&L, trial balance, simplified cash flow built; reconciliation has a `reconciledAt` field but no matching UI/flow yet)
- FR-5.7 Recurring transactions, budgets, approvals, reminders 🟡 (recurring templates + manual run, budgets + progress, and approval-threshold routing all built; reminders are Phase 09 — Notifications — scope)
- FR-5.8 QR-based receipt verification ✅ (public verification endpoint)
- FR-5.9 Immutable posted financial records ✅ (see NFR-2)
- 🔴 None of the above is yet integration-tested against a live database — see IMPLEMENTATION_STATUS.md "Blockers."

## Phase 12 — Reporting & Analytics
- FR-12.1 Cross-module reports (financial, farm, land, audit, operations) ✅ (8 reports: financial summary, balance sheet, trial balance, farm performance, animal growth, land, audit log, operations)
- FR-12.2 Exportable in common formats (CSV/Excel/PDF) ✅ (hand-written OOXML writer for Excel, avoiding a vulnerable transitive dependency — DECISIONS.md)
- FR-12.3 Filterable by date range, role-gated to who may see financial data ✅ (server-enforced per report; the report picker only ever offers what the caller's role allows)
- FR-12.4 Exported figures match what's shown on screen exactly ✅ (one shared report-table model renders the on-screen table and every export format)

## Phase 13 — Offline Mode & Synchronization
- FR-13.1 Encrypted offline drafts ✅ (write-outbox via `flutter_secure_storage`, same encryption mechanism as session tokens)
- FR-13.2 Secure synchronization with the central backend ✅ (idempotency keys prevent duplicate posts on retry)
- FR-13.3 Duplicate-submission and conflicting-update detection ✅ (idempotency keys for duplicate submission; `If-Match`/412 for conflicting edits)
- FR-13.4 Clear synchronization status in the UI ✅ (top-bar sync indicator + pending/failed item sheet with retry/discard)
- FR-13.5 Never silently overwrite a posted financial record ✅ (posted entries are immutable by design already — NFR-2 — and the outbox only ever queues new writes, never edits)
- FR-13.6 Data integrity verification after sync ✅ (a replayed/retried request is verified server-side to carry the exact same body as the original before being treated as a duplicate; any mismatch is rejected rather than silently accepted)
- See [OFFLINE_SYNC.md](OFFLINE_SYNC.md) for full detail and scope boundaries (write-outbox, not a full offline read cache).

## Phases 06–11, 14–15

Not yet re-verified in this document's checklist format — see the corresponding module document for each (linked from [README.md](README.md)), [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for verified detail, and CLAUDE.md for the authoritative phase definitions.
