# Carlys Admin — image multi-stage (Next.js standalone).
# Contexte de build attendu : la RACINE du monorepo.
#   docker build -f apps/admin/Dockerfile .

FROM node:22-alpine AS base
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
RUN corepack enable
WORKDIR /repo

# ── Dépendances + build ───────────────────────────────────────────────────────
FROM base AS build
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:3000
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml .npmrc ./
COPY packages ./packages
COPY apps/admin ./apps/admin
# Les pages /privacy et /terms lisent ces deux fichiers Markdown AU BUILD
# (pages statiques) : le contexte doit les contenir, le conteneur final non.
# Le .dockerignore racine ré-inclut docs/legal pour cette raison.
COPY docs/legal ./docs/legal
# Une image de production ne doit jamais servir un texte légal inachevé :
# tant que docs/legal porte un marqueur [À COMPLÉTER : …], `next build`
# échoue en listant les marqueurs (src/lib/legal-documents.ts). Pour une
# image locale ou de recette : --build-arg LEGAL_PLACEHOLDERS=allow
ARG LEGAL_PLACEHOLDERS=forbid
ENV LEGAL_PLACEHOLDERS=$LEGAL_PLACEHOLDERS
RUN pnpm install --frozen-lockfile --filter "@carlys/admin..."
RUN pnpm --filter "@carlys/admin..." run build

# ── Image d'exécution ─────────────────────────────────────────────────────────
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3001
WORKDIR /app

COPY --from=build /repo/apps/admin/.next/standalone ./
COPY --from=build /repo/apps/admin/.next/static ./apps/admin/.next/static
COPY --from=build /repo/apps/admin/public ./apps/admin/public

USER node
EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3001/ || exit 1

CMD ["node", "apps/admin/server.js"]
