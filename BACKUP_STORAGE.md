# Cloud Backup & Storage (Phase 10)

**Status: not started.** The dashboard reference mockup shows a "Cloud Backup Status" widget with Google Drive/iCloud/OneDrive/Dropbox connections; the current Flutter app shows an honest "not built yet" placeholder in that spot instead.

## Planned scope (from CLAUDE.md §Phase 10)

- Encrypted backup and restore
- Google Drive integration via official OAuth authorization
- Apple-compatible iCloud/CloudKit or document-provider workflow
- OneDrive, Dropbox, and S3-compatible storage adapters
- Scheduled and manual backups
- Backup integrity verification before restoration
- Connection status, last backup time, failure, and storage-usage display
- User-managed connected storage accounts

## Notes for when this phase starts

- "Adapter" is the right mental model — a common `BackupProvider` interface with one implementation per cloud service, so adding a new provider doesn't touch the core backup logic.
- Backup content must be encrypted before it leaves the device/server, not rely on the storage provider's own encryption-at-rest alone.
- "Verify integrity before restoration" implies checksums or a manifest — a destructive restore should never proceed on an unverified or partial backup.
- OAuth credentials for each provider are exactly the kind of "AI API credentials"-adjacent secret CLAUDE.md §4 requires encrypting at rest — same handling as planned for [AI_AUTOMATION.md](AI_AUTOMATION.md)'s provider keys.
