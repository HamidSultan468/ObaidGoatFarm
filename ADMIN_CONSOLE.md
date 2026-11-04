# Super Admin Control Panel (Phase 03/04 — Admin half)

**Status: 🟡 core built.** User and workspace management with MFA-gated owner operations exist end-to-end (backend + Flutter), verified by static checks (type-check, `flutter analyze`, tests) but not yet against a live database. Feature flags, licensing, API settings, themes, and the system-log viewer are not built yet.

## What's built

- **Backend** (`backend/src/modules/admin/`): `GET /admin/workspaces`, `PATCH /admin/workspaces/:id/status`, `GET /admin/users`, `PATCH /admin/users/:id/status`, `PATCH /admin/users/:id/global-role` — see [API_CONTRACTS.md](API_CONTRACTS.md).
- **Authorization**: `GlobalRolesGuard` (platform role) + `MfaRequiredGuard` (MFA must be enabled) stacked on every mutation — the literal implementation of CLAUDE.md's "Protect critical owner operations with MFA and audit logging." Reads are available to `ADMIN` too; mutations are `SUPER_ADMIN_OWNER`-only. See [ROLES_PERMISSIONS.md](ROLES_PERMISSIONS.md).
- **MFA (TOTP)**: full enrollment flow (`/auth/mfa/setup` → `verify-setup`), step-up login, and disable-with-proof — see [SECURITY.md](SECURITY.md) and DECISIONS.md D010/D012.
- **Flutter Admin Console screen** (`app/lib/features/admin/`): tabs for Workspaces (toggle active/inactive) and Users (toggle active/inactive); the Super Admin Owner row is protected from self-modification in the UI (and server-side regardless). Only visible in the sidebar to `SUPER_ADMIN_OWNER`/`ADMIN`, with a server-side redirect guard for anyone who navigates to `/admin` directly without the role.
- **Session/device management**: `GET /auth/sessions` / `DELETE /auth/sessions/:id`, surfaced in the Flutter Settings screen — not admin-console-specific, but the same "owner-level account control" spirit, available to every user for their own sessions.

## Not yet built (from CLAUDE.md §Phase 03/§Phase 04)

- Global feature activation/deactivation controls (needs a feature-flag schema — not yet designed)
- Individual client product licensing and activation
- Per-feature toggles shown in the reference mockup (AI Assistant, Voice Commands, WhatsApp Control, Multi-Client System, Advanced Reports) — waiting on those features existing at all
- API settings management (AI/WhatsApp provider credentials — see [AI_AUTOMATION.md](AI_AUTOMATION.md); `EncryptionService` already exists and is ready to store them)
- Theme management
- System logs viewer (the `AuditLog` table is fully populated already; just needs a query endpoint + screen)

## Notes

- Workspace invites (`POST /workspaces/:id/members`, OWNER/ADMIN-within-that-workspace) are a *tenant-level* operation, distinct from this platform-level admin console — don't conflate the two role axes (see [ROLES_PERMISSIONS.md](ROLES_PERMISSIONS.md)).
- "Global feature activation/deactivation" suggests a feature-flag table scoped globally (and possibly per-workspace) — a schema addition, not yet designed.
