# System Architecture

## Overview

Tangent Smart Manager is a multi-tenant financial and business management platform with four client surfaces (Android, iOS, Web, Windows) sharing one backend API. See [DECISIONS.md](DECISIONS.md) for the reasoning behind each choice below.

```
┌─────────────────────────────────────────────────────────┐
│                     Flutter Client                        │
│   (Android · iOS · Web · Windows — one Dart codebase)     │
│   lib/features/*  (dashboard, accounting, goat_farm, …)   │
│   lib/core/ (api client, auth, theming, l10n: en/ur)       │
└───────────────────────────┬─────────────────────────────┘
                             │ HTTPS / JSON (REST), JWT bearer
┌───────────────────────────▼─────────────────────────────┐
│                      NestJS Backend                       │
│  modules/auth        — login, refresh, MFA, sessions      │
│  modules/admin       — Super Admin control panel           │
│  modules/workspaces  — tenant & membership management      │
│  modules/accounting  — double-entry ledger (Phase 05)      │
│  modules/goat-farm    — animal records (Phase 06)          │
│  modules/land        — land/property records (Phase 07)   │
│  modules/documents   — file storage, OCR (Phase 08)        │
│  modules/notifications — in-app/push/email (Phase 09)      │
│  modules/backup      — cloud backup adapters (Phase 10)    │
│  modules/ai          — AI provider gateway (Phase 11)      │
│  modules/whatsapp    — WhatsApp Business integration        │
│  common/             — guards, interceptors, pipes, audit   │
└───────────────────────────┬─────────────────────────────┘
                             │ Prisma ORM
┌───────────────────────────▼─────────────────────────────┐
│                   PostgreSQL (primary datastore)           │
│   Row-level multi-tenant isolation via workspaceId          │
└───────────────────────────────────────────────────────────┘
```

## Client — Flutter

- One Dart codebase targets Android, iOS, Web, and Windows.
- `lib/core/` holds cross-cutting concerns: the typed API client, auth/token storage, theming (navy/"Modern Blue" per the approved dashboard reference), and `en`/`ur` localization (Urdu renders RTL).
- `lib/features/<domain>/` holds one feature module per business domain (dashboard, accounting, goat_farm, land, documents, notifications, settings, admin), each with its own `data/`, `domain/`, `presentation/` layers.
- State management, navigation, and local persistence choices are documented in `app/README.md` once the Flutter project is scaffolded (pending SDK availability — see IMPLEMENTATION_STATUS.md).

## Backend — NestJS

- Modular-by-domain: one Nest module per business domain, mirroring the Flutter feature split so API contracts stay easy to trace from either side.
- **Auth**: JWT access tokens (short-lived) + hashed refresh tokens persisted in `refresh_tokens`, rotated on use. MFA (TOTP) for Super Admin Owner operations per CLAUDE.md §3 Phase 03.
- **Authorization**: a `WorkspaceGuard` resolves the caller's `WorkspaceMembership` and attaches `{ workspaceId, role }` to the request; a `RolesGuard` checks required roles/permissions declared on each route. Both run on every tenant-scoped request — no module trusts client-supplied `workspaceId` alone.
- **Validation**: all input DTOs use `class-validator` decorators; a global `ValidationPipe` runs in whitelist/forbid-non-whitelisted mode.
- **Audit logging**: a `AuditInterceptor` writes to `audit_logs` for any mutating request on a tenant-scoped resource (who, what, when, before/after where applicable).
- **Money**: all monetary fields are Prisma `Decimal` (`numeric(18,4)` in Postgres). Application code performs money arithmetic through a single `Money` utility backed by `decimal.js` — see DECISIONS.md D004. No `number`/`Float` is ever used for an amount.
- **Errors**: a global `HttpExceptionFilter` normalizes error responses to a single shape (`{ statusCode, code, message, details? }`) and logs server-side with request correlation IDs.

## Database — PostgreSQL via Prisma

- Schema: `backend/prisma/schema.prisma`.
- Multi-tenancy: every tenant-scoped table carries `workspaceId`; see DECISIONS.md D005 for the isolation strategy.
- Posted financial records (`JournalEntry` once `postedAt` is set) are immutable at the application layer — corrections go through a reversing entry (`reversalOfId`), never an update/delete, per CLAUDE.md §3.
- Migrations are managed with `prisma migrate`; see DEPLOYMENT.md for the migration process once written.

## Cross-cutting concerns

| Concern | Approach |
|---|---|
| Multi-tenant isolation | `workspaceId` on every tenant row + `WorkspaceGuard` on every request (DECISIONS.md D005) |
| RBAC | `GlobalRole` (platform-level) + `WorkspaceRole` (per-tenant) enums, enforced server-side only |
| Audit trail | `AuditLog` table + `AuditInterceptor`, append-only |
| Localization | English/Urdu, selectable per user (`User.preferredLanguage`); Urdu renders RTL on the client |
| Money | `Decimal`, never `Float`; centralized `Money` utility |
| Secrets (AI/API keys) | Encrypted at rest (Phase 11); never logged |

## Status

This document describes the Phase 02/03/04 foundation as implemented so far. It will be extended module-by-module as Phases 05–15 are built. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for what is actually built and verified today versus what this document describes as the target shape.
