# Notification System (Phase 09)

**Status: not started.** The dashboard reference mockup shows a notification bell and preview panel; the current Flutter app has a real (non-functional, honest) bell icon and the schema has no notification table yet.

## Planned scope (from CLAUDE.md §Phase 09)

- In-app and mobile push notifications
- Email and approved messaging-platform integrations
- Manual notification controls for the Super Admin Owner
- Targeted notifications to selected users and Admins
- Automatic notification rules (e.g. vaccination due, low stock, payment received — as seen in the reference mockup)
- Owner-configurable recipients, categories, and delivery channels
- Schedules, delivery tracking, retry handling, logs
- Per-user notification preferences and quiet hours

## Notes for when this phase starts

- Needs a `Notification` (or similarly named) table with `workspaceId`, recipient, channel, status, and delivery-attempt tracking — not yet designed.
- Push notification delivery requires platform-specific setup (FCM for Android, APNs for iOS) — neither is configured.
- Automatic rules (e.g. "vaccination reminder") are inherently cross-module — they'll be triggered by events in [GOAT_FARM.md](GOAT_FARM.md), [ACCOUNTING.md](ACCOUNTING.md), etc., so this module's event/trigger design should be generic rather than hardcoded per source module.
