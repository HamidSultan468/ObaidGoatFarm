# Security

This document describes the security controls actually implemented in the codebase today. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for what is verified vs. written-but-unverified.

## Authentication

- Passwords are hashed with bcrypt (12 salt rounds) — never stored or logged in plaintext. Minimum password length: 12 characters (`backend/src/modules/auth/dto/register.dto.ts`).
- Access tokens are short-lived JWTs (default 15 minutes, configurable via `JWT_ACCESS_EXPIRES_IN`). They are never persisted server-side.
- Refresh tokens are opaque random values (512 bits), stored server-side only as a SHA-256 hash (`backend/src/modules/auth/auth.service.ts`). The raw token is never written to the database or logs.
- Refresh tokens rotate on every use: using one revokes it and issues a new pair, so a replayed/stolen refresh token is single-use.
- `ENCRYPTION_KEY`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `CORS_ORIGIN` (outside development — DECISIONS.md D042), and all other required configuration are validated at process boot (`backend/src/config/env.validation.ts`) — the app refuses to start with missing/malformed secrets rather than running insecurely.
- **Multi-factor authentication (TOTP)**: a user can enable MFA (`POST /auth/mfa/setup` → `verify-setup`), after which login becomes two-step — `POST /auth/login` returns a short-lived, purpose-scoped challenge token (`{ mfaRequired: true, mfaToken }`) instead of real session tokens, and `POST /auth/mfa/login` exchanges that token plus a 6-digit code for a real session. The challenge token is rejected everywhere else: `JwtStrategy.validate()` rejects any token carrying a `purpose` claim outright, before even looking up the user (DECISIONS.md D041 — this was a real, live-verified MFA-bypass bug until the Phase 14 security pass found and fixed it; see "Phase 14 findings" below). See DECISIONS.md D010/D012.
- Disabling MFA (`POST /auth/mfa/disable`) requires a currently-valid TOTP code, not just an active session — a hijacked session alone cannot turn protection off.

## Secrets encryption at rest

- `EncryptionService` (`backend/src/common/crypto/encryption.service.ts`) provides AES-256-GCM encrypt/decrypt, keyed by `ENCRYPTION_KEY` (32 bytes, hex, required at boot). Each encrypted value gets its own random IV.
- Currently used for the MFA TOTP secret (`User.mfaSecretEncrypted`) — never stored in plaintext. Designed to be reused for AI/WhatsApp provider credentials once Phase 11 is built (DECISIONS.md D011), rather than each feature inventing its own encryption.

## Authorization

- **Secure by default**: every route requires a valid JWT unless explicitly annotated `@Public()` (`JwtAuthGuard`, applied globally in `AppModule`).
- **Tenant isolation**: `WorkspaceGuard` re-resolves the caller's `WorkspaceMembership` against the database on every request to a `:workspaceId`-scoped route. A client-supplied workspace claim is never trusted on its own (DECISIONS.md D005).
- **Per-workspace role-based access**: `RolesGuard` + `@Roles(...)` enforce per-workspace role requirements (`OWNER`/`ADMIN`/`MANAGER`/`STAFF`/`VIEWER`) server-side.
- **Platform-level role-based access**: `GlobalRolesGuard` + `@GlobalRoles(...)` gate the Super Admin control panel (`/admin/*`) by platform `GlobalRole` (`SUPER_ADMIN_OWNER`/`ADMIN`/`USER`) — a separate, independent axis from workspace roles (see [ROLES_PERMISSIONS.md](ROLES_PERMISSIONS.md)).
- **MFA-gated owner operations**: `MfaRequiredGuard` additionally blocks any route it's applied to unless the caller's account has MFA enabled — applied to every mutating `/admin/*` endpoint, satisfying CLAUDE.md §3's "protect critical owner operations with MFA" literally (not just logging the action, but requiring MFA to perform it at all).

## Transport & request hardening

- `helmet()` sets standard security headers on every response.
- CORS is restricted to an explicit allowlist (`CORS_ORIGIN` env var), not wildcard-open.
- Global rate limiting via `@nestjs/throttler` (default: 100 requests/minute per client), applied before authentication so it also protects public endpoints like `/auth/login` against brute force.
- All input DTOs are validated with `class-validator` under a global `ValidationPipe` in whitelist + `forbidNonWhitelisted` mode — unexpected fields are rejected, not silently dropped or accepted.

## Audit trail

- `AuditInterceptor` writes an `AuditLog` row for every mutating request (POST/PUT/PATCH/DELETE), capturing actor, workspace, action, entity type/id, and IP address. A failed audit write never silently passes — it's logged loudly even though it doesn't block the request.
- Admin console mutations and MFA setup/enable/disable/session-revoke all carry an explicit `@AuditAction(...)` name rather than relying on the generic method+path fallback, so the audit log reads clearly for the most sensitive actions.

## Money / financial integrity

- All monetary values are `Decimal` (PostgreSQL `numeric(18,4)`), never `Float`. See DECISIONS.md D004 and `backend/src/common/money/money.ts`.
- Posted `JournalEntry` records are immutable at the application layer; corrections require a reversing entry (`reversalOfId`), never an update or delete (CLAUDE.md §3).

## Tenant isolation in the ledger write path

`LedgerService.postEntry` verifies that every account (and that it is active), contact, animal and land parcel an entry references belongs to the entry's workspace before anything is written (DECISIONS.md D024). This closed a real cross-tenant posting hole found during Phase 3. Farm, land and document endpoints apply the same rule to every id they accept (parents, dams/sires, lease counterparties, attachment owners).

## Uploaded documents

- AES-256-GCM encrypted on disk; SHA-256 integrity check on download; storage paths never returned to clients and guarded against escaping `STORAGE_DIR`.
- File type detected from content (JPEG/PNG/WEBP/PDF only — no SVG/HTML), 10 MB limit, sanitized filenames, `Cache-Control: private, no-store` and `X-Content-Type-Options: nosniff` on downloads.
- Upload requires OWNER/ADMIN/MANAGER/STAFF; deletion requires OWNER/ADMIN/MANAGER. Every upload/delete is audit-logged.

## Phase 4 integrations

- **Secrets at rest:** AI keys, WhatsApp access tokens and app secrets are AES-256-GCM encrypted; APIs return only hints. Backups use a separate HKDF-derived key.
- **AI output is untrusted:** structured output is parsed, every id is matched against the workspace's own records, and the result is only a draft. Approval goes through the normal validated services (ledger, approval threshold, tenant checks) with an atomic claim.
- **WhatsApp webhook:** public route, but nothing is processed without a valid HMAC-SHA256 signature over the raw body (constant-time compare). Phones are trusted only after a one-time code (hashed, 15 min, 5 attempts). Webhook retries are de-duplicated.
- **Backups:** restore never overwrites; restoring an uploaded file requires ownership of the source workspace; integrity is verified before any restore; download/restore/delete are audit-logged.
- **Notifications:** users can only read or change their own; platform announcements need Super Admin Owner + MFA; recipients of manual messages must be members.

## Input typing

Request validation never converts types implicitly (DECISIONS.md D022): money, weights and areas must be decimal strings, so a client float can't slip through as a converted string.

## A bug this security model itself caught

While building the first real role-gated endpoint (`POST /workspaces/:id/members`), `RolesGuard` was found to have been registered as a *global* guard — which would have run it before the route-level `WorkspaceGuard` ever populated the membership it checks, rejecting every role-gated request unconditionally. Fixed by making `RolesGuard` route-level only, always paired explicitly with `WorkspaceGuard`. See IMPLEMENTATION_STATUS.md and [ROLES_PERMISSIONS.md](ROLES_PERMISSIONS.md).

## Phase 14 findings (Security & QA pass, 2026-11-05)

A consolidated security sweep (`backend/scripts/e2e/security-qa.e2e.mjs`, 60 live checks) across every module at once, beyond the per-module checks each earlier phase already ran:

1. **Critical — MFA bypass, fixed (DECISIONS.md D041).** The MFA challenge token worked as a full bearer token on every protected route, because `JwtStrategy.validate()` never checked the `purpose` claim it carries. An attacker holding only a correct password (no access to the second factor) could reach every API the account can, completely defeating MFA. Found live, fixed, and re-verified live in the same pass.
2. **Hardening gap, fixed (DECISIONS.md D042).** `CORS_ORIGIN` wasn't validated at boot and silently defaulted to allow-all outside development if unset — inconsistent with every other required secret's fail-fast behavior. Now required and validated.
3. **Confirmed correct, no change needed**: tenant isolation on every `:workspaceId`-scoped module (reads and writes), rate limiting, refresh-token rotation and single-use, logout revocation, password/registration validation, no SQL injection surface (the only raw query in the codebase is a hardcoded, parameter-free `SELECT 1` health check — everything else goes through Prisma's parameterized query builder), whitelist input validation (`forbidNonWhitelisted` actually rejects unexpected fields, live-verified), and that stored text (including deliberately SQL- and script-tag-shaped probe strings) round-trips as inert literal data.
4. **Accessibility** (not a backend concern, but part of the same QA pass — see TESTING_QA.md): two icon-only buttons missing screen-reader labels, and KPI card label text failing WCAG AA contrast, both fixed (DECISIONS.md D040); one color-contrast question (the shared `borderLight`/`borderDark` divider color) deliberately left open for a dedicated design pass rather than changed blindly.

## Not yet implemented

- Identity documents as a dedicated, extra-restricted category (Phase 03) — general encrypted document storage exists (above), but there is no separate identity-document type with narrower permissions yet.
- Formal third-party penetration testing — still not run (that needs an external firm/service, a Phase 15-adjacent, account-gated item). What *is* done: the scripted live security/QA sweep above, which is real live-fire testing of this codebase's own attack surface, just not an independent outside review.

## Reporting

Internal project — no external disclosure process defined yet. Add one before any external release (Phase 15).
