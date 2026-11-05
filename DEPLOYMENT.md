# Deployment

This describes the deployment approach. **Nothing described here has actually been deployed** — this project has not left local development. Docker Desktop is now installed (2026-11-05), but its WSL2 backend can't start because CPU virtualization is disabled in this machine's BIOS (see DECISIONS.md D044) — a physical reboot-into-firmware step, not something solvable from here — so the artifacts below are written and reviewed but **not yet verified by an actual build/run**. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for current state, and the "Blocked on external accounts" section below for what genuinely can't proceed further without you.

## Environments (planned)

| Environment | Purpose | Status |
|---|---|---|
| Local development | Current work | Active (this machine) |
| Staging | Pre-production verification | Not provisioned |
| Production | Live system | Not provisioned |

## Backend

- **Runtime**: Node.js 24 (NestJS). A multi-stage `backend/Dockerfile` exists (`deps` → `build` → `runtime`, final image is `node:24-slim`) — Prisma 7 has no native query-engine binary, so there's no Alpine/glibc binary-target concern to work around. **Not yet built or run** (Docker Desktop is installed but its WSL2 backend is blocked on a BIOS setting — see "Blocked on external accounts"); review before trusting it.
- **Database**: PostgreSQL. Connection config is environment-variable driven (`DATABASE_URL`, see `backend/.env.example`) and, as of Prisma 7, also requires `backend/prisma.config.ts` for CLI operations (migrate/seed) — see DECISIONS.md D008.
- **Migrations**: `prisma migrate deploy` for production (never `migrate dev`, which is for local development only and can prompt for destructive resets). Deliberately **not** run automatically by the Docker image's `CMD` — on a scaled deployment every replica would start simultaneously and race to apply the same migration. Run it as its own one-off step first: `docker compose run --rm backend npx prisma migrate deploy`.
- **Secrets**: JWT signing secrets, database credentials, and AI/WhatsApp API credentials must come from environment variables or a secrets manager — never committed. `.env` is gitignored; only `.env.example` (with no real values) is tracked. `CORS_ORIGIN` is now a required, validated boot-time variable outside development (DECISIONS.md D042) — the app refuses to start without it rather than silently allowing every origin.
- **Local prod-like stack**: `docker-compose.yml` at the repo root (backend + PostgreSQL, backend reads secrets from `backend/.env`). Also written but not yet run.

## Continuous Integration

`.github/workflows/ci.yml` — **written but not yet exercised** (needs a push/PR to actually run, and the `backend-e2e` job needs three CI-only secrets added under the repo's Settings → Secrets: `CI_ENCRYPTION_KEY`, `CI_JWT_ACCESS_SECRET`, `CI_JWT_REFRESH_SECRET` — any random hex string works, these are never real production secrets). Three jobs:
- `backend`: `tsc --noEmit`, the full Vitest unit suite, `npm audit --omit=dev`.
- `flutter`: `flutter analyze`, `flutter test`.
- `backend-e2e`: boots a real PostgreSQL service container, runs migrations, starts the actual compiled server, and runs the live E2E scripts (`backend/scripts/e2e/*.e2e.mjs`) against it — matching how this project has verified every phase so far, not just unit-testing in isolation. `notifications.e2e.mjs` is excluded for now (needs `smtp-sink.mjs` running alongside it).

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
- [x] CI pipeline defined (`.github/workflows/ci.yml`) — 🟡 not yet exercised; needs a push/PR and three repo secrets (see "Continuous Integration" above)
- [ ] Production secrets provisioned via a secrets manager, not `.env` files
- [ ] Database migrations verified against a staging copy before production
- [ ] Monitoring/alerting in place
- [ ] Backup/restore tested, not just configured
- [x] Security review completed (Phase 14) — see SECURITY.md and TESTING_QA.md; one critical finding (MFA bypass, DECISIONS.md D041) and one hardening gap (D042) found and fixed
- [ ] Android/iOS store listings prepared, signing configured

## Blocked on external accounts (need you, not more code)

Everything above this line was buildable without outside access. These genuinely cannot proceed further without accounts, payment, or decisions only you can make:

- **Hosting provider** — where the backend/database/Flutter web build actually run (a VPS, Render/Railway/Fly.io, AWS/GCP/Azure, ...). No infrastructure is provisioned anywhere yet.
- **Domain name + TLS** — needed for a real `CORS_ORIGIN`/`API_BASE_URL` and HTTPS in production.
- **Managed PostgreSQL** (or a self-hosted instance on the chosen host) for production data — today's database is local-only.
- **Android**: a Google Play Console account ($25 one-time) and a release signing keystore.
- **iOS**: an Apple Developer account ($99/year) and a macOS build host (this is a Windows machine) — e.g. a GitHub Actions macOS runner or a physical/cloud Mac.
- **CPU virtualization is disabled in this machine's BIOS/UEFI firmware** (confirmed 2026-11-05 — see DECISIONS.md D044): Docker Desktop is installed, but its WSL2 backend refuses to start without it. Fix: restart the computer, enter BIOS/UEFI setup (commonly F2 at boot on this Dell OptiPlex 7010), enable "Intel Virtualization Technology" / VT-x under the CPU or security settings, save, and reboot into Windows. Only then can the Dockerfile/compose file above actually be built and run for the first time.
- **Monitoring/alerting and log aggregation** — needs a chosen provider (or self-hosted stack) and, for most options, an account/subscription.

Tell me which of these you'd like to set up (or provide the accounts/credentials for) and I'll pick this phase back up from there.
