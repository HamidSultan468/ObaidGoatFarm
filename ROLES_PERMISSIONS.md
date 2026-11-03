# Roles & Permissions

## Two role dimensions

The platform has two independent role axes, matching CLAUDE.md §3's Super Admin Owner / Admin / User model plus per-tenant roles:

1. **GlobalRole** (`User.globalRole`) — platform-wide, used only for the Super Admin control panel (Phase 03/04, not yet built):
   - `SUPER_ADMIN_OWNER` — the platform owner; the only role that will be allowed to perform owner-level operations (global feature flags, client licensing) once the admin console is built. Intended to require MFA (not yet implemented).
   - `ADMIN` — platform operator without owner-level privileges.
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
3. `RolesGuard` + `@Roles(...)` — rejects the request if the resolved `WorkspaceMembership.role` isn't in the route's declared allowed roles.

See `backend/src/common/guards/` for the implementation and SECURITY.md for the broader security model.

## What exists vs. what's planned

- ✅ Schema and guards implemented (`GlobalRole`, `WorkspaceRole`, `WorkspaceGuard`, `RolesGuard`, `@Roles()`).
- ✅ First real use: `POST /workspaces/:id/members` requires `OWNER` or `ADMIN` via `@UseGuards(WorkspaceGuard, RolesGuard)` + `@Roles('OWNER', 'ADMIN')`. Building this surfaced and fixed a real bug — `RolesGuard` had been registered globally, which would have run it before `WorkspaceGuard` ever populated the membership it checks; see DECISIONS.md and IMPLEMENTATION_STATUS.md.
- ⬜ A granular, configurable permission system beyond these five fixed `WorkspaceRole` values (if the business needs finer-grained permissions than role-based) is not yet designed — revisit if Phase 03's "granular role-based permissions" requirement needs more than these five roles once real modules exist.
- ⬜ Super Admin control panel UI/endpoints.
