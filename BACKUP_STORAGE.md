# Backup & Restore (Phase 10)

**Status: built and verified live (2026-11-04) with on-server storage; cloud providers open.**

## What exists

- **Backup file** (`backend/src/modules/backup/`): every record the workspace owns plus its documents, as gzip'd JSON, encrypted with AES-256-GCM using a key derived (HKDF) from `ENCRYPTION_KEY`. Password hashes, MFA secrets, sessions and notifications are never included.
- **Manual and automatic** backups — automatic daily at 02:00, keeping the newest N (default 7, owner-adjustable); manual backups are kept until deleted.
- **Verification** before restore (and on demand): tamper check, checksum, format version, all references, every journal entry balances.
- **Restore** always creates a new workspace with new ids and all links remapped, in one transaction; the original workspace is never touched. From a stored backup (owner) or an uploaded `.tsmbak` (owner of the source workspace, or Super Admin Owner).
- **Status:** last backup, failures (CRITICAL notification), number and size of backups, document storage; dashboard Backup card; workspace switcher to open a restored copy.
- **Storage:** `BackupStorageProvider` interface; today `LocalDiskBackupProvider` under `STORAGE_DIR/backups`.

## Operational notes

- A backup can only be restored on a server with the same `ENCRYPTION_KEY`. Keep the key safe and backed up separately.
- On-server backups protect against mistakes and bad data, not against losing the server: copy `STORAGE_DIR` (and run PostgreSQL backups) off the machine until a cloud provider is connected.

## Not yet built

- Google Drive, OneDrive, Dropbox, S3-compatible and iCloud adapters — each needs a developer app / credentials from the owner. They implement the existing `BackupStorageProvider` interface.
