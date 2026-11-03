# Database Operations

Operational reference for working with the database day-to-day. For *what* the schema contains and *why*, see [DATA_MODEL.md](DATA_MODEL.md). For the Prisma 7 driver-adapter setup specifically, see DECISIONS.md D008.

## Current status

🔴 No PostgreSQL instance is available in this development environment yet — see [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) "Blockers". Everything below is the intended workflow once one exists.

## Configuration

Two files carry database configuration, for different reasons (a Prisma 7 requirement, not a choice — see DECISIONS.md D008):
- `backend/.env` (gitignored) — `DATABASE_URL`, read by the running application via `PrismaService`.
- `backend/prisma.config.ts` (tracked) — reads the same `DATABASE_URL` via `dotenv/config`, used by the Prisma CLI for migrations/seeding.

## Common commands

```bash
cd backend

# Apply schema changes as a new migration (local development)
npx prisma migrate dev --name <describe_the_change>

# Apply existing migrations without creating a new one (CI/production)
npx prisma migrate deploy

# Regenerate the Prisma Client after any schema.prisma change
npx prisma generate

# Inspect data visually
npx prisma studio

# Seed a local database with the first Super Admin Owner account
SEED_OWNER_EMAIL=you@example.com SEED_OWNER_PASSWORD=... npx prisma db seed
```

## Migration discipline

- Never hand-edit a generated migration SQL file after it's been applied anywhere other migrations might depend on it.
- Never use `prisma migrate reset` (drops all data) outside of local development — it is explicitly destructive.
- Posted financial records are immutable at the application layer (see [DATA_MODEL.md](DATA_MODEL.md)) — this is enforced in code, not by the database alone; a migration should never need to bypass it.
- Per CLAUDE.md Global Rule 9: never hard-delete posted accounting records, in a migration or otherwise.

## Local environment setup (once PostgreSQL is installed)

1. Create a database (name arbitrary, `tangent_smart_manager` is the default assumed in `.env.example`).
2. Set `DATABASE_URL` in `backend/.env` to point at it.
3. Run `npx prisma migrate dev` to create the schema.
4. Run the seed command above to create the first owner account.
