# Notification System (Phase 09)

**Status: built and verified live (2026-11-04); push notifications open.**

## What exists

- **Inbox** (`backend/src/modules/notifications/`): one notification per recipient, read/unread, links to the related screen. Flutter: bell with unread badge + preview panel (top bar), Notifications screen.
- **Automatic rules** (`notification-rules.service.ts`, every 10 minutes and on "Check now"): health follow-up due within 3 days or overdue, kidding within 7 days or overdue, lease ending within 30 days or ended, transactions awaiting approval. Event notifications: backup failed/restored, WhatsApp drafts to review. A per-user `dedupeKey` means each reminder is sent once; overdue escalates once.
- **Owner control:** per workspace, each rule can be switched off and its recipient roles chosen (defaults in `notification-rules.config.ts`). Delivery log for email.
- **Manual sending:** workspace owner/admin to roles or members; Super Admin Owner platform announcements (MFA).
- **Preferences:** per user and category — in-app and/or email; quiet hours in the user's time zone (default Asia/Karachi). Announcements always reach the inbox.
- **Email:** SMTP (`SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` in `backend/.env`). Retries after 1, 5, 15, 60 minutes, up to 5 attempts; quiet hours delay sending. Without SMTP, email choices are disabled in the app.

## Not yet built

- Push notifications (Firebase Cloud Messaging for Android/web, APNs for iOS) — requires the owner's Firebase/Apple accounts.
- Low-stock alerts (Inventory isn't built yet).
