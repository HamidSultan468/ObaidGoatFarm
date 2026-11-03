# Implementation Status

Last updated: 2026-11-03

This document tracks what is actually built and verified, as distinct from what is planned. Per CLAUDE.md §5/§13: nothing is marked done here until it has been run/tested, and unverified work is explicitly called out as such.

## Legend
- ✅ Done — implemented and verified (ran/tested successfully)
- 🟡 In progress — code written, not yet fully verified
- ⬜ Not started
- 🔴 Blocked — see note

## Phase 01 — Project Audit
- ✅ Repository inspected: was an empty documentation scaffold (29 empty `.md` files + 1 reference image), no code, no git history.
- ✅ Git repository initialized (`git init`), `.gitignore` added.
- ✅ Stack decisions recorded — see [DECISIONS.md](DECISIONS.md).

## Phase 02 — System Foundation
- ✅ Backend project scaffolded: NestJS 12 + TypeScript 6, ESM, Vitest for tests (`backend/`).
- ✅ Dependencies installed and verified: `@nestjs/config`, `@nestjs/jwt`, `@nestjs/passport`, `passport-jwt`, `@nestjs/throttler`, `@prisma/client`, `@prisma/adapter-pg`, `pg`, `bcrypt`, `helmet`, `@nestjs/swagger`, `class-validator`, `class-transformer`, `decimal.js`, `dotenv`, `prisma` (dev).
- ✅ Environment validation (`src/config/env.validation.ts`) — app fails fast at boot if required env vars are missing/malformed.
- ✅ Global error handling (`HttpExceptionFilter`) — normalized error shape + correlation IDs, server-side logging.
- ✅ Global security middleware: `helmet()`, CORS allowlist, global `ValidationPipe` (whitelist + forbid-unknown-properties), global rate limiting (`ThrottlerGuard`, 100 req/min default).
- ✅ Centralized `Money` value object (`src/common/money/money.ts`) backed by `decimal.js` — never raw floats. Unit-tested (`money.spec.ts`): **9/9 tests passing** (verified run), including a proof that `0.1 + 0.2 !== 0.3` in native JS but is exact through `Money`.
- ✅ Prisma schema authored (`backend/prisma/schema.prisma`): Workspace (tenant), User, WorkspaceMembership (RBAC), RefreshToken, UserDevice, AuditLog, and minimal Account/JournalEntry/JournalLine + Animal stubs (full accounting/goat-farm modules are Phases 05/06).
- ✅ Prisma 7 driver-adapter setup (`prisma.config.ts`, `PrismaService` using `@prisma/adapter-pg`) — Prisma 7 removed the Rust query engine and the `datasource.url` schema field; this is a mandatory breaking-change migration, not optional (DECISIONS.md D008). `prisma generate`: **verified succeeding**.
- ✅ Whole-backend type-check (`tsc --noEmit`): **verified passing, 0 errors** (two real type errors found and fixed along the way: an Express `params` array-type narrowing gap in `WorkspaceGuard`, and a JWT `expiresIn` option type mismatch in `AuthService`).
- 🔴 **Database migrations NOT applied** — no PostgreSQL instance is available in this environment (not installed, no Docker to run a container either). `prisma migrate dev` has not been run against a real database, so the schema and the auth flow are **unverified against an actual Postgres engine**. You said you'd install PostgreSQL locally — this is the one remaining blocker. See "Blockers" below.
- ⬜ CI pipeline, linting-on-commit hooks.
- ✅ Flutter client project scaffolded (`app/`) for Android, iOS, Web, Windows (`flutter create`). Flutter SDK 3.47.9 / Dart 3.13.7 installed locally (no-admin manual install — DECISIONS.md D007).
- ✅ `flutter analyze`: **verified 0 issues**. `flutter test`: **verified 1/1 passing**.
- ✅ `flutter doctor`: Windows desktop and Chrome/web targets fully functional on this machine (Visual Studio Build Tools + Windows SDK already present). Android needs the `cmdline-tools` component (minor, not blocking — Android SDK itself is present). iOS cannot be built/verified from Windows (needs macOS/Xcode — known limitation, not new).

## Phase 03 — Authentication & Administration
- ✅ Auth module implemented: register, login, refresh (rotating, hashed refresh tokens), logout, **`GET /auth/me`** for session restore (`src/modules/auth/`).
- ✅ Password hashing via bcrypt (12 rounds); refresh tokens stored as SHA-256 hashes, never plaintext.
- ✅ JWT access tokens (short-lived, configurable) via Passport JWT strategy.
- ✅ Global "secure by default" posture: every route requires a valid JWT unless explicitly marked `@Public()`.
- ✅ `WorkspaceGuard` (tenant isolation) + `RolesGuard` (per-workspace RBAC) + `@Roles()` decorator.
- ✅ **Bug found and fixed**: `RolesGuard` was initially registered as a global `APP_GUARD`, which would have run it *before* the route-level `WorkspaceGuard` ever populated `request.membership` — any role-gated route would have rejected every request immediately. Fixed by making `RolesGuard` route-level only, applied together with `WorkspaceGuard` via `@UseGuards(WorkspaceGuard, RolesGuard)` wherever role checks are needed (caught while building the first real consumer of this combination — see Workspaces below).
- ✅ `AuditInterceptor` — writes an `AuditLog` row for every mutating (POST/PUT/PATCH/DELETE) request.
- ✅ Workspace module (`src/modules/workspaces/`): `POST /workspaces` (create, caller becomes `OWNER`), `GET /workspaces` (list mine), `GET /workspaces/:id` (tenant-guarded), `POST /workspaces/:id/members` (invite, `OWNER`/`ADMIN` only) — the first real use of the `WorkspaceGuard` + `RolesGuard` + `@Roles()` combination together. This closes the "no workspace creation flow" gap noted below in earlier revisions of this file.
- ✅ Type-checks clean against the generated Prisma client (see Phase 02), including after adding the workspaces module.
- 🔴 **Not yet integration-tested end-to-end** — needs a live database (same blocker as Phase 02).
- ⬜ MFA (TOTP) for Super Admin Owner operations.
- ⬜ Super Admin control panel (backend endpoints + Flutter screens).
- ⬜ Device management UI (schema exists: `UserDevice`).

## Phase 04 — Dashboard & UI
- ✅ Flutter app wired end-to-end: `main.dart` → Riverpod `ProviderScope` → `go_router` with auth-aware redirects → login screen → authenticated dashboard shell.
- ✅ Theme matching the approved reference image (`app/lib/core/theme/`): navy sidebar, "Modern Blue" accent, semantic KPI card colors, light + dark mode.
- ✅ Login screen (`app/lib/features/auth/presentation/login_screen.dart`) wired to real `POST /auth/login`, with loading/error states.
- ✅ Session persistence: JWT/refresh tokens in `flutter_secure_storage` (via a `TokenStorage` abstraction for testability), automatic 401 → refresh → retry interceptor in `ApiClient`, session restore via `GET /auth/me` on app start.
- ✅ Dashboard shell matching the reference layout: navy sidebar with all 12 module nav items, top bar (search, notifications icon, user menu with real logout), responsive KPI card row, module section cards.
- ✅ **Honest data policy applied**: KPI cards show a genuine `$0.00` zero state (no workspace or financial data exists yet — workspace creation and the accounting engine are Phase 05 scope) instead of the reference mockup's illustrative numbers. Sections with no backing module yet (Financial Overview, Goat Farm widget, Recent Transactions, Cloud Backup) show an explicit "not built yet, planned for Phase X" card — never fake data or a dead button. Other sidebar destinations route to a real, honest "not built yet" screen rather than doing nothing.
- ✅ Workspace flow wired: after login, `WorkspaceController` loads the user's workspaces; none existing redirects to a real "Create your workspace" screen (`CreateWorkspaceScreen`, calling `POST /workspaces`); the dashboard shows the selected workspace's real name instead of a placeholder message.
- 🔴 **Not yet run end-to-end against the real backend** — needs the backend running against a live database (same blocker as Phase 02/03) to actually log in and see the authenticated shell in a browser/desktop window, per CLAUDE.md's UI-testing requirement. The code is written and statically verified (`flutter analyze` 0 issues, widget test passing with a mocked backend dependency) but a real login has not been exercised yet.
- ⬜ Multi-workspace switching UI (backend already returns the full list via `GET /workspaces`; the app currently auto-selects the first one and has no switcher).
- ⬜ Global search, notification center, Quick Actions (all require backend modules that don't exist yet).
- ⬜ Urdu translation strings (the RTL/locale *mechanism* is wired — `supportedLocales: [en, ur]` — but no actual Urdu string resources exist yet; only the English UI has been written).

## Phases 05–15
- ⬜ Not started (out of scope for this engagement's current starting point — see DECISIONS.md D006).

## Blockers — require your input

1. **PostgreSQL** — you said you'd install it locally. Once it's running, tell me the connection details (or just confirm the default `postgresql://postgres:postgres@localhost:5432` works) and I'll point `backend/.env`'s `DATABASE_URL` at it, run `prisma migrate dev`, and do the first real end-to-end verification: register a user, log in from the Flutter app, see the authenticated dashboard. This is the only thing blocking real (not just static) verification of everything built so far.

Nothing else is currently blocking.
