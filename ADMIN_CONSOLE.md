# Super Admin Control Panel (Phase 03/04 — Admin half)

**Status: 🟡 core built and verified live**, including the system logs viewer (2026-11-05). Feature flags, per-client licensing, AI/WhatsApp API settings management, and theme management remain not built — see below.

## What's built

- **Backend** (`backend/src/modules/admin/`): `GET /admin/workspaces`, `PATCH /admin/workspaces/:id/status`, `GET /admin/users`, `PATCH /admin/users/:id/status`, `PATCH /admin/users/:id/global-role`, `GET /admin/logs` — see [API_CONTRACTS.md](API_CONTRACTS.md).
- **Authorization**: `GlobalRolesGuard` (platform role) + `MfaRequiredGuard` (MFA must be enabled) stacked on every mutation — the literal implementation of CLAUDE.md's "Protect critical owner operations with MFA and audit logging." Reads are available to `ADMIN` too; mutations are `SUPER_ADMIN_OWNER`-only. See [ROLES_PERMISSIONS.md](ROLES_PERMISSIONS.md).
- **MFA (TOTP)**: full enrollment flow (`/auth/mfa/setup` → `verify-setup`), step-up login, and disable-with-proof — see [SECURITY.md](SECURITY.md) and DECISIONS.md D010/D012.
- **Flutter Admin Console screen** (`app/lib/features/admin/`): tabs for Workspaces, Users, and **System Logs** (every `AuditLog` row platform-wide — not scoped to one workspace like the per-workspace audit report in Reports & Analytics — with an action-text filter and the actor/workspace resolved to an email/name rather than a raw id). The Super Admin Owner row is protected from self-modification in the UI (and server-side regardless). Only visible in the sidebar to `SUPER_ADMIN_OWNER`/`ADMIN`, with a server-side redirect guard for anyone who navigates to `/admin` directly without the role.
  - **Workspaces tab** (2026-11-05 expansion): beyond the active/inactive toggle, each row now shows the owner's name/email, the active-member role breakdown (e.g. "1 owner, 2 staff"), the creation date, and a basic activity footprint (animal/land-parcel/transaction counts) — `AdminService.listWorkspaces` resolves this from the workspace's memberships and record counts server-side.
  - **Users tab** (2026-11-05 expansion): beyond the active/inactive toggle, each row now shows registration date, last login, preferred language, and every workspace the user belongs to with their role there — `AdminService.listUsers` resolves this from active `WorkspaceMembership` rows server-side.
- **Session/device management**: `GET /auth/sessions` / `DELETE /auth/sessions/:id`, surfaced in the Flutter Settings screen — not admin-console-specific, but the same "owner-level account control" spirit, available to every user for their own sessions. Sessions now carry a friendly device name/platform (e.g. "Windows PC", "iPhone/iPad") reported by the client at login, not just an opaque device id (2026-11-05 — see DECISIONS.md D045).

## Not yet built (from CLAUDE.md §Phase 03/§Phase 04)

- Global feature activation/deactivation controls (needs a feature-flag schema — not yet designed)
- Individual client product licensing and activation
- Per-feature toggles shown in the reference mockup (AI Assistant, Voice Commands, WhatsApp Control, Multi-Client System, Advanced Reports) — waiting on those features existing at all
- API settings management (AI/WhatsApp provider credentials — see [AI_AUTOMATION.md](AI_AUTOMATION.md); `EncryptionService` already exists and is ready to store them)
- Theme management (only one theme, "Modern Blue," exists — a switcher has nothing to switch to yet)

## Notes

- Workspace invites (`POST /workspaces/:id/members`, OWNER/ADMIN-within-that-workspace) are a *tenant-level* operation, distinct from this platform-level admin console — don't conflate the two role axes (see [ROLES_PERMISSIONS.md](ROLES_PERMISSIONS.md)).
- "Global feature activation/deactivation" suggests a feature-flag table scoped globally (and possibly per-workspace) — a schema addition, not yet designed.
