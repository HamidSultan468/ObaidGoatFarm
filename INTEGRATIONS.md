# External Integrations — Index

A consolidated index of every external system this platform integrates with. Each has its own detailed document; this page is the map.

| Integration | Phase | Document | Status |
|---|---|---|---|
| AI providers (multi-provider, encrypted credentials) | 11 | [AI_AUTOMATION.md](AI_AUTOMATION.md) | Not started |
| WhatsApp Business Platform | 11 | [WHATSAPP_INTEGRATION.md](WHATSAPP_INTEGRATION.md) | Not started |
| Google Drive | 10 | [BACKUP_STORAGE.md](BACKUP_STORAGE.md) | Not started |
| iCloud / CloudKit | 10 | [BACKUP_STORAGE.md](BACKUP_STORAGE.md) | Not started |
| OneDrive | 10 | [BACKUP_STORAGE.md](BACKUP_STORAGE.md) | Not started |
| Dropbox | 10 | [BACKUP_STORAGE.md](BACKUP_STORAGE.md) | Not started |
| S3-compatible storage | 10 | [BACKUP_STORAGE.md](BACKUP_STORAGE.md) | Not started |
| Push notifications (FCM/APNs) | 09 | [NOTIFICATIONS.md](NOTIFICATIONS.md) | Not started |
| Email delivery | 09 | [NOTIFICATIONS.md](NOTIFICATIONS.md) | Not started |

## Cross-cutting rule

Every credential for every integration above is a secret: encrypted at rest, never logged, never committed (see [SECURITY.md](SECURITY.md) and `.env.example`'s pattern of real values staying out of git). No integration is a hard dependency for core app functionality — per CLAUDE.md, manual/offline functionality must keep working if any external service is unavailable.
