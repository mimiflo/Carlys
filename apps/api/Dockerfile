# Carlys API — image multi-stage.
# Contexte de build attendu : la RACINE du monorepo.
#   docker build -f apps/api/Dockerfile .                              # image d'exécution
#   docker build -f apps/api/Dockerfile --target migrate -t carlys-api-migrate .
#
# Deux cibles, une règle : `prisma migrate deploy` s'exécute AVANT la bascule
# du trafic, par l'image `migrate`, jamais au démarrage du conteneur
# d'exécution (voir infrastructure/deployment/README.md).

FROM node:22-alpine AS base
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
RUN corepack enable
WORKDIR /repo

# ── Dépendances + build ───────────────────────────────────────────────────────
FROM base AS build
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml .npmrc ./
COPY packages ./packages
COPY apps/api ./apps/api
RUN pnpm install --frozen-lockfile --filter "@carlys/api..."
# Construit d'abord les packages du workspace, puis l'API (prebuild = prisma generate).
RUN pnpm --filter "@carlys/api..." run build

# ── Migrations : `prisma migrate deploy` avant la bascule ────────────────────
# Le CLI Prisma est une dépendance de développement : cet étage part de
# `build`, AVANT l'élagage, et embarque schéma + migrations. Il n'existe que
# pour cette commande, et se lance à part :
#   docker run --rm -e DATABASE_URL=… carlys-api-migrate
# Un code de sortie non nul doit interrompre le déploiement.
FROM build AS migrate
ENV NODE_ENV=production
# Le CLI ne cherche pas de mise à jour ni n'envoie de télémétrie depuis la production.
ENV CHECKPOINT_DISABLE=1
USER node
WORKDIR /repo/apps/api
ENTRYPOINT ["./node_modules/.bin/prisma", "migrate", "deploy"]

# ── Élagage des dépendances de développement ─────────────────────────────────
FROM build AS pruned
RUN pnpm prune --prod

# ── Image d'exécution ─────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /repo

COPY --from=pruned /repo/node_modules ./node_modules
COPY --from=pruned /repo/packages ./packages
COPY --from=pruned /repo/apps/api/node_modules ./apps/api/node_modules
COPY --from=pruned /repo/apps/api/dist ./apps/api/dist
COPY --from=pruned /repo/apps/api/package.json ./apps/api/package.json
COPY --from=pruned /repo/apps/api/prisma ./apps/api/prisma

USER node
WORKDIR /repo/apps/api
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health/live || exit 1

CMD ["node", "dist/main"]
