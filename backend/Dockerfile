# Phase 15 prep (DEPLOYMENT.md). Written but NOT YET BUILT OR RUN — Docker
# isn't installed on the current dev machine, so this has only been
# reviewed, not verified. Confirm with a real `docker build` + container
# run before relying on it for an actual deployment.
#
# Multi-stage: `deps`/`build` keep devDependencies (TypeScript, the `prisma`
# CLI for running `prisma migrate deploy`); the final `runtime` stage is
# node:22-slim with nothing but what the compiled app needs to run.
#
# Deliberately NOT auto-running migrations in CMD: on a scaled deployment
# every replica would start simultaneously and race to apply the same
# migration. Run `prisma migrate deploy` as its own one-off step (e.g.
# `docker compose run --rm backend npx prisma migrate deploy`) before
# starting/scaling the app — see DEPLOYMENT.md.

FROM node:24-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM deps AS build
COPY . .
RUN npx prisma generate --schema=prisma/schema.prisma
RUN npm run build

FROM node:24-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY package.json ./
EXPOSE 3000
USER node
CMD ["node", "dist/main.js"]
