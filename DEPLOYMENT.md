# Deployment

This describes the *intended* deployment approach. **Nothing described here has been deployed yet** — this project has not left local development. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for current state.

## Environments (planned)

| Environment | Purpose | Status |
|---|---|---|
| Local development | Current work | Active (this machine) |
| Staging | Pre-production verification | Not provisioned |
| Production | Live system | Not provisioned |

## Backend

- **Runtime**: Node.js (NestJS). Containerization (Docker) is the expected packaging approach once infrastructure decisions are made — not yet set up (Docker isn't even installed on the current dev machine).
- **Database**: PostgreSQL. Connection config is environment-variable driven (`DATABASE_URL`, see `backend/.env.example`) and, as of Prisma 7, also requires `backend/prisma.config.ts` for CLI operations (migrate/seed) — see DECISIONS.md D008.
- **Migrations**: `prisma migrate deploy` for production (never `migrate dev`, which is for local development only and can prompt for destructive resets).
- **Secrets**: JWT signing secrets, database credentials, and (once Phase 11 exists) AI/WhatsApp API credentials must come from environment variables or a secrets manager — never committed. `.env` is gitignored; only `.env.example` (with no real values) is tracked.

## Flutter clients

- **Android**: release build via `flutter build appbundle`, signed with a release keystore (not yet created). Requires the Android `cmdline-tools` component (currently missing on the dev machine) and Play Console setup.
- **iOS**: requires a macOS build host (Xcode) — cannot be built from this Windows development machine. A cloud Mac CI (e.g. a GitHub Actions macOS runner, or a service like Codemagic) will be needed, or a physical Mac.
- **Web**: `flutter build web`, deployable as static assets to any static host or CDN.
- **Windows**: `flutter build windows`, produces a native executable; distribution channel (MSIX/installer vs. plain executable) not yet decided.

The API base URL is injected at build time via `--dart-define=API_BASE_URL=...` (see `app/lib/core/api/api_client.dart`) so the same codebase targets different backend environments without code changes.

## Monitoring, logging, alerting

Not yet set up. The backend currently logs to stdout via NestJS's built-in `Logger` (see `HttpExceptionFilter`, `PrismaService`) with correlation IDs on errors — a real log aggregation/alerting pipeline is a Phase 15 concern.

## Backups & disaster recovery

Not yet relevant — no production data exists. Will be designed alongside [BACKUP_STORAGE.md](BACKUP_STORAGE.md) (Phase 10) and revisited for production database backup strategy specifically in Phase 15.

## Release checklist (to be expanded before first release)

- [ ] Infrastructure decided and provisioned (hosting, managed Postgres, container orchestration or PaaS)
- [ ] CI pipeline running tests on every change
- [ ] Production secrets provisioned via a secrets manager, not `.env` files
- [ ] Database migrations verified against a staging copy before production
- [ ] Monitoring/alerting in place
- [ ] Backup/restore tested, not just configured
- [ ] Security review completed (Phase 14)
- [ ] Android/iOS store listings prepared, signing configured
