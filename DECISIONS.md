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
