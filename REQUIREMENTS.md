# Requirements

Source of truth for scope: CLAUDE.md's 15-phase master workflow. This document restates it as checkable functional and non-functional requirements, grouped by phase, with build status. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for verified-vs-planned detail and [ACCEPTANCE_CRITERIA.md](ACCEPTANCE_CRITERIA.md) for how each requirement is confirmed done.

Status tags: ✅ built & verified · 🟡 partially built · ⬜ not started.

## Non-functional requirements (apply to every phase)

| ID | Requirement | Status |
|---|---|---|
| NFR-1 | No floating-point arithmetic for money; all amounts are `Decimal` | ✅ (`Money`, Prisma `Decimal`) |
| NFR-2 | Posted financial records are immutable; corrections via reversal only | 🟡 (schema supports it; no posting UI yet) |
| NFR-3 | Strict multi-tenant data isolation, enforced server-side | ✅ (`WorkspaceGuard`) |
| NFR-4 | Server-side role-based permissions, never trusted from client | ✅ (`RolesGuard`) |
| NFR-5 | Complete audit trail for mutating actions | ✅ (`AuditInterceptor`) |
| NFR-6 | Secure authentication and session management | ✅ (bcrypt, rotating JWT refresh) |
| NFR-7 | English + Urdu user-selectable interface language | 🟡 (mechanism wired; Urdu strings not yet written) |
| NFR-8 | Runs on Android, iOS, Web, Windows from one codebase | 🟡 (scaffolded for all four; only Windows/Web runnable from this dev machine — iOS needs macOS) |
| NFR-9 | No mock functionality or placeholder data in shipped UI | ✅ (enforced as a standing design rule — see `NotYetAvailableCard`/`ModulePlaceholderScreen`) |

## Phase 02 — System Foundation
- FR-2.1 Centralized backend with modular architecture ✅
- FR-2.2 Database with migration tooling ✅ (schema + tooling ready; migrations unapplied, no DB yet)
- FR-2.3 Centralized error handling and logging ✅
- FR-2.4 Reusable UI theming/component foundation ✅ (`AppTheme`, `AppColors`)
- FR-2.5 Application foundations for all four platforms 🟡

## Phase 03 — Authentication & Administration
- FR-3.1 Super Admin Owner / Admin / User roles ✅ (schema + enforcement; no admin UI yet)
- FR-3.2 Granular role-based permissions ✅ (workspace-level); 🟡 finer-grained permissions beyond 5 fixed roles not yet needed/designed
- FR-3.3 Multi-client / multi-workspace management 🟡 (create/list/invite built, backend + Flutter, honest-zero-state verified via static checks; no workspace *switcher* UI yet, unverified against a live database)
- FR-3.4 Per-client product licensing/activation ⬜
- FR-3.5 User profiles, identity documents, device management 🟡 (schema exists for devices; no UI)
- FR-3.6 Super Admin control panel ⬜
- FR-3.7 Global feature activation/deactivation ⬜
- FR-3.8 MFA + audit logging on owner operations 🟡 (audit logging done; MFA not built)

## Phase 04 — Dashboard & UI
- FR-4.1 Dashboard matching the approved reference design ✅
- FR-4.2 Navy sidebar + top navigation ✅
- FR-4.3 Financial KPI cards and charts 🟡 (cards built, honest zero-state; chart not built — needs Phase 05 data)
- FR-4.4 Quick Actions, global search ⬜
- FR-4.5 Notification previews, recent transactions ⬜ (honest placeholders shown)
- FR-4.6 Goat Farm overview widget, backup status widget ⬜ (honest placeholders shown)
- FR-4.7 Responsive desktop/tablet/mobile layouts 🟡 (responsive grid built; not yet tested on real mobile viewport)
- FR-4.8 Every visible control performs a real function ✅ (standing rule — no dead buttons; unbuilt destinations say so explicitly)

## Phases 05–15

Not yet started — see the corresponding module document for each (linked from [README.md](README.md)) and CLAUDE.md for the authoritative phase definitions. Each module document states its own requirements once design work for that phase begins, rather than speculating here ahead of that work.
