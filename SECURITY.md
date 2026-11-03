# Security

This document describes the security controls actually implemented in the codebase today. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for what is verified vs. written-but-unverified.

## Authentication

- Passwords are hashed with bcrypt (12 salt rounds) — never stored or logged in plaintext. Minimum password length: 12 characters (`backend/src/modules/auth/dto/register.dto.ts`).
- Access tokens are short-lived JWTs (default 15 minutes, configurable via `JWT_ACCESS_EXPIRES_IN`). They are never persisted server-side.
- Refresh tokens are opaque random values (512 bits), stored server-side only as a SHA-256 hash (`backend/src/modules/auth/auth.service.ts`). The raw token is never written to the database or logs.
- Refresh tokens rotate on every use: using one revokes it and issues a new pair, so a replayed/stolen refresh token is single-use.
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` and all other required configuration are validated at process boot (`backend/src/config/env.validation.ts`) — the app refuses to start with missing/malformed secrets rather than running insecurely.

## Authorization

- **Secure by default**: every route requires a valid JWT unless explicitly annotated `@Public()` (`JwtAuthGuard`, applied globally in `AppModule`).
- **Tenant isolation**: `WorkspaceGuard` re-resolves the caller's `WorkspaceMembership` against the database on every request to a `:workspaceId`-scoped route. A client-supplied workspace claim is never trusted on its own (DECISIONS.md D005).
- **Role-based access**: `RolesGuard` + `@Roles(...)` enforce per-workspace role requirements (`OWNER`/`ADMIN`/`MANAGER`/`STAFF`/`VIEWER`) server-side. There is a separate platform-level `GlobalRole` (`SUPER_ADMIN_OWNER`/`ADMIN`/`USER`) for the Super Admin control panel, not yet built.

## Transport & request hardening

- `helmet()` sets standard security headers on every response.
- CORS is restricted to an explicit allowlist (`CORS_ORIGIN` env var), not wildcard-open.
- Global rate limiting via `@nestjs/throttler` (default: 100 requests/minute per client), applied before authentication so it also protects public endpoints like `/auth/login` against brute force.
- All input DTOs are validated with `class-validator` under a global `ValidationPipe` in whitelist + `forbidNonWhitelisted` mode — unexpected fields are rejected, not silently dropped or accepted.

## Audit trail

- `AuditInterceptor` writes an `AuditLog` row for every mutating request (POST/PUT/PATCH/DELETE), capturing actor, workspace, action, entity type/id, and IP address. A failed audit write never silently passes — it's logged loudly even though it doesn't block the request.

## Money / financial integrity

- All monetary values are `Decimal` (PostgreSQL `numeric(18,4)`), never `Float`. See DECISIONS.md D004 and `backend/src/common/money/money.ts`.
- Posted `JournalEntry` records are immutable at the application layer; corrections require a reversing entry (`reversalOfId`), never an update or delete (CLAUDE.md §3).

## Not yet implemented

- MFA (TOTP) for Super Admin Owner operations (CLAUDE.md §3 Phase 03) — schema has `User.mfaEnabled`/`mfaSecretEncrypted` fields, logic not yet built.
- Encryption at rest for AI provider API credentials (Phase 11) — not yet built.
- Identity document storage/encryption (Phase 03/08) — not yet built.
- Formal penetration/security testing (Phase 14) — not yet run; no database is available in the current dev environment to exercise these paths end-to-end (see IMPLEMENTATION_STATUS.md "Blockers").

## Reporting

Internal project — no external disclosure process defined yet. Add one before any external release (Phase 15).
