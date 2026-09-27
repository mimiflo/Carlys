# Carlys Admin — image multi-stage (Next.js standalone).
# Contexte de build attendu : la RACINE du monorepo.
#   docker build -f apps/admin/Dockerfile .

FROM node:22-alpine AS base
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
RUN corepack enable
WORKDIR /repo

# ── Dépendances + build ───────────────────────────────────────────────────────
#
# LES MANIFESTES D'ABORD, LES SOURCES ENSUITE, et les arguments de build au
# plus près de `next build` — même raisonnement que apps/api/Dockerfile :
# l'installation ne dépend que du lockfile et des package.json. Avant, toute
# retouche d'une source, de design-tokens ou de ui (dont l'admin ne dépend
# pas), et même un `--build-arg` différent, rejouait `pnpm install` : la
# construction « la garde légale mord toujours » d'images-ci, qui ne change
# QUE LEGAL_PLACEHOLDERS, refaisait toute l'installation (26 s mesurées).
#
# SEULS LES PAQUETS QUE L'ADMIN UTILISE : api-contracts (le code), eslint-config
# et typescript-config (tsconfig.json étend
# ../../packages/typescript-config/nextjs.json). Une dépendance de workspace
# ajoutée à l'admin doit l'être aussi ici — l'oublier fait échouer
# l'installation, et images-ci le voit.
FROM base AS build
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml .npmrc ./
COPY packages/api-contracts/package.json ./packages/api-contracts/
COPY packages/eslint-config/package.json ./packages/eslint-config/
COPY packages/typescript-config/package.json ./packages/typescript-config/
COPY apps/admin/package.json ./apps/admin/
RUN pnpm install --frozen-lockfile --filter "@carlys/admin..."
COPY packages/api-contracts ./packages/api-contracts
COPY packages/eslint-config ./packages/eslint-config
COPY packages/typescript-config ./packages/typescript-config
COPY apps/admin ./apps/admin
# Les pages /privacy et /terms lisent ces deux fichiers Markdown AU BUILD
# (pages statiques) : le contexte doit les contenir, le conteneur final non.
# Le .dockerignore racine ré-inclut docs/legal pour cette raison.
COPY docs/legal ./docs/legal
# L'adresse de l'API est INLINÉE dans le JavaScript du navigateur par
# `next build` (et lue par les en-têtes de sécurité de next.config.ts).
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:3000
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
# Une image de production ne doit jamais servir un texte légal inachevé :
# tant que docs/legal porte un marqueur [À COMPLÉTER : …], `next build`
# échoue en listant les marqueurs (src/lib/legal-documents.ts). Pour une
# image locale ou de recette : --build-arg LEGAL_PLACEHOLDERS=allow
ARG LEGAL_PLACEHOLDERS=forbid
ENV LEGAL_PLACEHOLDERS=$LEGAL_PLACEHOLDERS
RUN pnpm --filter "@carlys/admin..." run build

# ── Image d'exécution ─────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3001
WORKDIR /app

COPY --from=build /repo/apps/admin/.next/standalone ./
COPY --from=build /repo/apps/admin/.next/static ./apps/admin/.next/static
# `output: 'standalone'` n'embarque NI .next/static NI public/ : les deux se
# recopient à la main, c'est la marche à suivre documentée par Next.js.
# apps/admin/public/ est donc versionné (un .gitkeep suffit) même vide : sans
# lui, ce COPY échoue — « not found » — et l'image ne se construit pas.
COPY --from=build /repo/apps/admin/public ./apps/admin/public

USER node
EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3001/ || exit 1

CMD ["node", "apps/admin/server.js"]
