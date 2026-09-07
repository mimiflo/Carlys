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
# `build`, donc AVANT la fabrication de l'arbre de production qui l'écarte, et
# embarque schéma + migrations. Il n'existe que pour cette commande, et se
# lance à part :
#   docker run --rm -e DATABASE_URL=… carlys-api-migrate
# Un code de sortie non nul doit interrompre le déploiement.
FROM build AS migrate
ENV NODE_ENV=production
# Le CLI ne cherche pas de mise à jour ni n'envoie de télémétrie depuis la production.
ENV CHECKPOINT_DISABLE=1
USER node
WORKDIR /repo/apps/api
ENTRYPOINT ["./node_modules/.bin/prisma", "migrate", "deploy"]

# ── Arbre de production autonome ─────────────────────────────────────────────
# `pnpm prune --prod` NE CONVIENT PAS ici : il est cadré sur le projet racine,
# ni récursif ni filtré. Le package.json racine n'ayant aucune dépendance de
# production, l'élagage vidait `apps/api/node_modules` (31 entrées → 0) et
# faisait disparaître les liens @carlys/* — alors que @carlys/api-contracts et
# @carlys/shared-config sont des dépendances de PRODUCTION de l'API
# (src/config/env.schema.ts, src/app/app.module.ts). L'image se construisait
# mais mourait au démarrage sur « Cannot find module '@carlys/shared-config' ».
#
# `pnpm deploy` fabrique au contraire un répertoire AUTONOME : dépendances de
# production seules, liens de workspace résolus vers de vraies copies (dist
# des paquets @carlys compris). `--legacy` est requis tant que le workspace
# n'active pas `inject-workspace-packages`.
FROM build AS deploy
RUN pnpm deploy --filter=@carlys/api --prod --legacy /prod
# `pnpm deploy` reconstruit node_modules depuis le store : le client Prisma
# engendré au prebuild n'y est PAS (piège classique). On le régénère dans
# l'arbre déployé avec le CLI de l'étage `build` — dépendance de
# développement, absente de l'arbre de production, d'où l'appel par chemin.
RUN cd /prod && /repo/apps/api/node_modules/.bin/prisma generate

# ── Image d'exécution ─────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

# L'arbre déployé se suffit à lui-même : plus de node_modules racine ni de
# packages/ à recopier, les paquets @carlys vivent dans ./node_modules.
COPY --from=deploy /prod/node_modules ./node_modules
COPY --from=deploy /prod/dist ./dist
COPY --from=deploy /prod/package.json ./package.json
COPY --from=deploy /prod/prisma ./prisma

USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health/live || exit 1

CMD ["node", "dist/main"]
