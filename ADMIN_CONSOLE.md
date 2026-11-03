# Super Admin Control Panel (Phase 03/04 — Admin half)

**Status: not started.** The dashboard reference mockup shows an "Admin Control Panel" widget (feature toggles, user management, API settings, themes, system logs); the current build has the `GlobalRole.SUPER_ADMIN_OWNER` role defined in the schema and enforced in guards, but no admin-specific endpoints or screens exist yet.

## Planned scope (from CLAUDE.md §Phase 03/§Phase 04)

- Complete Super Admin Owner control panel
- Global feature activation/deactivation controls
- Individual client product licensing and activation
- User management (the reference mockup shows per-feature on/off toggles: AI Assistant, Voice Commands, WhatsApp Control, Multi-Client System, Advanced Reports)
- API settings management (likely where AI/WhatsApp provider credentials from [AI_AUTOMATION.md](AI_AUTOMATION.md) get configured)
- Theme management
- System logs viewer (surfacing `AuditLog`, which already exists)
- MFA + audit logging required specifically for owner-level operations, beyond the audit logging already applied platform-wide

## What already exists to build on

- `GlobalRole` enum (`SUPER_ADMIN_OWNER` / `ADMIN` / `USER`) on `User` — see [ROLES_PERMISSIONS.md](ROLES_PERMISSIONS.md).
- `AuditLog` table, already populated for every mutating request.
- No route in the codebase currently checks `GlobalRole` (only `WorkspaceRole`, via `RolesGuard`) — a `GlobalRolesGuard` or equivalent needs to be built for owner-only endpoints.

## Notes for when this phase starts

- MFA (TOTP) for owner operations is explicitly required by CLAUDE.md and is tracked as not-yet-built in [SECURITY.md](SECURITY.md) and [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) — this is likely the first piece to build here, since every other owner-only feature should sit behind it.
- "Global feature activation/deactivation" suggests a feature-flag table scoped globally (and possibly per-workspace) — a schema addition, not yet designed.
