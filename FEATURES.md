# Features

Feature inventory by module, with build status. This is the practical, user-facing companion to [REQUIREMENTS.md](REQUIREMENTS.md) (which states requirements) and [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) (which tracks verification). Status tags: ✅ built & working · 🟡 partial · ⬜ planned, not built.

## Authentication & Account
- ✅ Register with email + password
- ✅ Log in / log out
- ✅ Session persists across app restarts (secure token storage + auto-refresh)
- ⬜ Forgot/reset password
- ⬜ Multi-factor authentication
- ⬜ Device management ("log out other devices")
- ⬜ Change email / change password from settings

## Workspaces (multi-tenant)
- 🟡 Create a workspace — backend endpoint built (`POST /workspaces`); no Flutter UI yet, and unverified against a live database
- 🟡 Invite a member to a workspace — backend endpoint built (`POST /workspaces/:id/members`, OWNER/ADMIN only); no Flutter UI yet
- 🟡 List/switch between workspaces — `GET /workspaces` built; no Flutter UI yet
- ✅ Per-workspace role management — `WorkspaceRole` enforced server-side via `WorkspaceGuard` + `RolesGuard`

## Dashboard
- ✅ KPI summary cards (Income / Expenses / Profit / Bank Balance) — honest zero state until Phase 05 exists
- ✅ Sidebar navigation to every module
- ⬜ Financial trend chart
- ⬜ Quick Actions panel
- ⬜ Global search
- ⬜ Recent transactions feed
- ⬜ Notification preview panel

## Financial Management (Phase 05)
- ⬜ Everything — see [ACCOUNTING.md](ACCOUNTING.md)

## Goat Farm Management (Phase 06)
- ⬜ Everything — see [GOAT_FARM.md](GOAT_FARM.md)

## Land Management (Phase 07)
- ⬜ Everything — see [LAND_MANAGEMENT.md](LAND_MANAGEMENT.md)

## Documents & Records (Phase 08)
- ⬜ Everything — see [DOCUMENTS_MEDIA.md](DOCUMENTS_MEDIA.md)

## Notifications (Phase 09)
- ⬜ Everything — see [NOTIFICATIONS.md](NOTIFICATIONS.md)

## Cloud Backup (Phase 10)
- ⬜ Everything — see [BACKUP_STORAGE.md](BACKUP_STORAGE.md)

## AI & WhatsApp (Phase 11)
- ⬜ Everything — see [AI_AUTOMATION.md](AI_AUTOMATION.md) and [WHATSAPP_INTEGRATION.md](WHATSAPP_INTEGRATION.md)

## Reporting & Analytics (Phase 12)
- ⬜ Everything — depends on Phase 05/06/07 data existing first

## Offline Mode (Phase 13)
- ⬜ Everything — see [OFFLINE_SYNC.md](OFFLINE_SYNC.md)

## Localization
- 🟡 English/Urdu locale mechanism wired (`supportedLocales`); no Urdu strings written yet
- ⬜ RTL layout verification pass for Urdu
