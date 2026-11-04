# Documents & Record Management (Phase 08)

**Status: core built and verified live (2026-11-04).**

## What exists

- **Attachments** (`backend/src/modules/documents/`) on animals, land parcels, transactions, contacts, or as general documents; the owning record must be in the same workspace.
- **Storage**: AES-256-GCM encrypted files under `STORAGE_DIR/<workspaceId>/` (default `backend/storage/`, git-ignored); metadata and a SHA-256 in the `attachments` table; integrity verified on every download (DECISIONS.md D025).
- **Hardening**: type detected from file content (JPEG, PNG, WEBP, PDF only), 10 MB limit, sanitized filenames, `no-store` + `nosniff` downloads, RFC 6266 filenames (Urdu names preserved). Upload: OWNER/ADMIN/MANAGER/STAFF; delete: OWNER/ADMIN/MANAGER; both audit-logged.
- **Flutter**: reusable Photos & documents card (animal and land pages), My Records library (filter by module, search), universal **Add new** menu in the top bar.

## Operational notes

- Back up `STORAGE_DIR` together with the database, and keep `ENCRYPTION_KEY` safe: without the key the files cannot be decrypted.

## Not yet built

- Document scanning/OCR and voice-to-record drafts — need the AI integration ([AI_AUTOMATION.md](AI_AUTOMATION.md), Phase 11); extracted data must remain a draft until a human approves it.
- Ready-made and custom templates ([TEMPLATES.md](TEMPLATES.md)).
- Exports and record-history views.
- Cloud storage backends ([BACKUP_STORAGE.md](BACKUP_STORAGE.md), Phase 10).
