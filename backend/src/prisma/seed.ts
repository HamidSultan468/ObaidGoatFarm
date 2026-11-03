import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

/**
 * Creates the first Super Admin Owner account for a fresh environment.
 * Intended for local/dev setup only — never run against production with
 * these defaults. Reads credentials from env so nothing sensitive is
 * hardcoded in source.
 */
async function main(): Promise<void> {
  const email = process.env.SEED_OWNER_EMAIL;
  const password = process.env.SEED_OWNER_PASSWORD;
  const fullName = process.env.SEED_OWNER_NAME ?? 'Super Admin Owner';

  if (!email || !password) {
    throw new Error(
      'SEED_OWNER_EMAIL and SEED_OWNER_PASSWORD must be set in the environment to seed the owner account.',
    );
  }

  const passwordHash = await bcrypt.hash(password, 12);

  const owner = await prisma.user.upsert({
    where: { email },
    update: {},
    create: {
      email,
      passwordHash,
      fullName,
      globalRole: 'SUPER_ADMIN_OWNER',
    },
  });

  console.log(`Seeded Super Admin Owner: ${owner.email}`);
}

main()
  .catch((error: unknown) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
