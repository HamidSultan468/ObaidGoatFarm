import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

// Prisma 7 removed the Rust query engine and the `datasource.url` schema
// field — connection config for the CLI (migrate, studio, seed) lives here
// instead. See DECISIONS.md D008.
export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: 'node prisma/seed.ts',
  },
  datasource: {
    url: env('DATABASE_URL'),
  },
});
