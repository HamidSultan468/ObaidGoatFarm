# Tangent Smart Manager

A unified financial and business management platform — personal finance, household accounting, business records, land management, inventory, and goat farm management — for Android, iOS, Web, and Windows.

Built from a single [Flutter](https://flutter.dev) client (`app/`) against a [NestJS](https://nestjs.com) + PostgreSQL backend (`backend/`).

## Project status

This project is under active, phase-by-phase development. **Read [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) first** — it tracks exactly what is built and verified versus planned, and lists any current blockers. [DECISIONS.md](DECISIONS.md) explains why the stack was chosen. [CLAUDE.md](CLAUDE.md) is the governing development standard for this repository.

## Repository layout

```
backend/   NestJS API — auth, accounting engine, business modules, database
app/       Flutter client — Android, iOS, Web, Windows from one codebase
*.md       Project documentation (see "Documentation" below)
```

## Getting started

### Backend

```bash
cd backend
npm install
cp .env.example .env   # fill in DATABASE_URL and JWT secrets
npx prisma generate
npx prisma migrate dev # requires a running PostgreSQL instance
npm run start:dev
```

The API listens on `http://localhost:3000` by default. See [API_CONTRACTS.md](API_CONTRACTS.md) for the current endpoint list.

### Flutter app

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).

```bash
cd app
flutter pub get
flutter run -d windows   # or: chrome, android, ios
```

By default the app talks to `http://localhost:3000`. Override with:
```bash
flutter run --dart-define=API_BASE_URL=https://your-api.example.com
```

### Running tests

```bash
cd backend && npm test        # vitest — unit tests (no database required)
cd app && flutter test        # widget tests
cd app && flutter analyze     # static analysis
```

## Documentation

| Document | Covers |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture, client/backend/database design |
| [DATA_MODEL.md](DATA_MODEL.md) | Database schema and the reasoning behind it |
| [SECURITY.md](SECURITY.md) | Authentication, authorization, and data-protection controls actually implemented |
| [API_CONTRACTS.md](API_CONTRACTS.md) | Backend endpoint reference |
| [ROLES_PERMISSIONS.md](ROLES_PERMISSIONS.md) | Role model and how it's enforced |
| [REQUIREMENTS.md](REQUIREMENTS.md) | Functional and non-functional requirements |
| [FEATURES.md](FEATURES.md) | Feature list by module, with build status |
| [DESIGN.md](DESIGN.md) / [UI_UX.md](UI_UX.md) | Visual design system and UX principles |
| [TESTING_QA.md](TESTING_QA.md) | Testing strategy and current coverage |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Deployment targets and process |
| [WORKFLOW.md](WORKFLOW.md) | Development workflow for this repository |
| [ACCEPTANCE_CRITERIA.md](ACCEPTANCE_CRITERIA.md) | Definition of Done and per-feature acceptance criteria |
| [DECISIONS.md](DECISIONS.md) | Architectural decision log |
| [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) | What's actually built and verified, right now |

Module-specific plans (mostly not yet built — each document says so at the top): [ACCOUNTING.md](ACCOUNTING.md), [GOAT_FARM.md](GOAT_FARM.md), [LAND_MANAGEMENT.md](LAND_MANAGEMENT.md), [DOCUMENTS_MEDIA.md](DOCUMENTS_MEDIA.md), [NOTIFICATIONS.md](NOTIFICATIONS.md), [BACKUP_STORAGE.md](BACKUP_STORAGE.md), [AI_AUTOMATION.md](AI_AUTOMATION.md), [WHATSAPP_INTEGRATION.md](WHATSAPP_INTEGRATION.md), [ADMIN_CONSOLE.md](ADMIN_CONSOLE.md), [OFFLINE_SYNC.md](OFFLINE_SYNC.md), [TEMPLATES.md](TEMPLATES.md), [INTEGRATIONS.md](INTEGRATIONS.md), [DATABASE.md](DATABASE.md).

## Language policy

All code, identifiers, comments, commit messages, and documentation in this repository are in English, per [CLAUDE.md](CLAUDE.md) §1. The *application itself* supports English and Urdu as user-selectable interface languages.
