# Roles & Permissions

## Two role dimensions

The platform has two independent role axes, matching CLAUDE.md §3's Super Admin Owner / Admin / User model plus per-tenant roles:

1. **GlobalRole** (`User.globalRole`) — platform-wide, used for the Super Admin control panel (`/admin/*`):
   - `SUPER_ADMIN_OWNER` — the platform owner; the only role allowed to perform owner-level mutations (deactivate a workspace/user, reassign a platform role), and only when MFA is enabled on the account (`MfaRequiredGuard` — see SECURITY.md).
   - `ADMIN` — platform operator; can view the admin console (`GET /admin/workspaces`, `GET /admin/users`) but not mutate.
   - `USER` — everyone else. This is the default for every newly registered account.
2. **WorkspaceRole** (`WorkspaceMembership.role`) — scoped to a single tenant (`Workspace`):
   - `OWNER` — full control of that workspace.
   - `ADMIN` — manages workspace settings/members, not ownership transfer.
   - `MANAGER` — day-to-day operational access (expected: post transactions, manage records).
   - `STAFF` — restricted operational access (expected: data entry without approval rights).
   - `VIEWER` — read-only.

A `GlobalRole` never implies a `WorkspaceRole` — a Super Admin Owner has no workspace access unless they also hold a `WorkspaceMembership` row for that workspace. This keeps platform administration and tenant data access as separate, explicit grants (CLAUDE.md §4: "strict multi-tenant data isolation").

## Enforcement

Enforced server-side only, on every request, never trusted from the client:

1. `JwtAuthGuard` (global) — rejects any request without a valid access token, unless the route is `@Public()`.
2. `WorkspaceGuard` — for routes under a `:workspaceId` path param, re-resolves the caller's `WorkspaceMembership` from the database (never from the JWT payload) and attaches it to the request.
3. `RolesGuard` + `@Roles(...)` — rejects the request if the resolved `WorkspaceMembership.role` isn't in the route's declared allowed roles. Always applied together with `WorkspaceGuard`, never alone (see "A bug this caught" below).
4. `GlobalRolesGuard` + `@GlobalRoles(...)` — rejects the request if the caller's `GlobalRole` isn't in the route's declared allowed roles. Independent of 2/3 — used by `/admin/*` only.
5. `MfaRequiredGuard` — rejects the request unless the caller's account has MFA enabled. Stacked on top of `GlobalRolesGuard` for every mutating `/admin/*` route.

See `backend/src/common/guards/` for the implementation and SECURITY.md for the broader security model.

## A bug this caught

Building the first real role-gated endpoint (`POST /workspaces/:id/members`) surfaced a real ordering bug: `RolesGuard` had been registered as a *global* `APP_GUARD`, which runs before any route-level guard like `WorkspaceGuard` — so it would have checked the caller's role against an unpopulated `request.membership` and rejected every role-gated request unconditionally, every time. Fixed by making `RolesGuard` route-level only, always paired explicitly with `WorkspaceGuard` via `@UseGuards(WorkspaceGuard, RolesGuard)`. `GlobalRolesGuard` doesn't have this problem (it reads only from the JWT-derived `request.user`, not from a guard-populated field), so it's registered the same route-level way for consistency, not out of necessity.

## What exists vs. what's planned

- ✅ Schema and guards implemented: `GlobalRole`, `WorkspaceRole`, `WorkspaceGuard`, `RolesGuard`, `GlobalRolesGuard`, `MfaRequiredGuard`.
- ✅ Workspace-level: `POST /workspaces/:id/members` requires `OWNER` or `ADMIN`.
- ✅ Platform-level: `/admin/*` requires `SUPER_ADMIN_OWNER` or `ADMIN` to read, `SUPER_ADMIN_OWNER` + MFA enabled to mutate.
- ⬜ A granular, configurable permission system beyond these five fixed `WorkspaceRole` values (if the business needs finer-grained permissions than role-based) is not yet designed — revisit if Phase 03's "granular role-based permissions" requirement needs more than these five roles once real modules exist.
- ⬜ Flutter-side role-based UI hiding is partial — the Admin Console sidebar entry is hidden for non-admins, but most mutation buttons elsewhere are shown to everyone and rely on the server's real 403 (surfaced to the user) rather than being hidden client-side. This is intentional (the server is the source of truth) but means some roles will see actions they can't complete, with an error rather than the control simply not being there.
