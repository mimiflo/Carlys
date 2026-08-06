#!/usr/bin/env bash
# Installation locale de Carlys (projets TypeScript + infrastructure Docker).
set -euo pipefail

cd "$(dirname "$0")/.."

echo "── Vérification des prérequis ──────────────────────────────────────"
command -v node >/dev/null || { echo "Node.js >= 22 requis"; exit 1; }
command -v pnpm >/dev/null || { echo "pnpm requis (corepack enable)"; exit 1; }
command -v docker >/dev/null || { echo "Docker requis"; exit 1; }

echo "── Fichiers d'environnement ────────────────────────────────────────"
[ -f .env ] || { cp .env.example .env; echo "  .env créé depuis .env.example"; }
[ -f apps/api/.env ] || { cp apps/api/.env.example apps/api/.env; echo "  apps/api/.env créé"; }
[ -f apps/admin/.env.local ] || { cp apps/admin/.env.example apps/admin/.env.local; echo "  apps/admin/.env.local créé"; }

echo "── Installation des dépendances ────────────────────────────────────"
pnpm install

echo "── Build des packages partagés ─────────────────────────────────────"
pnpm --filter "./packages/**" build

echo "── Infrastructure Docker (PostgreSQL, Redis, Mailpit, MinIO) ───────"
docker compose up -d

echo "── Client Prisma ───────────────────────────────────────────────────"
pnpm prisma:generate

echo ""
echo "Terminé. Prochaines commandes utiles :"
echo "  pnpm dev            # API (3000) + Admin (3001)"
echo "  pnpm test           # tests de tous les projets"
echo "  ./scripts/bootstrap_mobile.sh   # app Flutter (nécessite le SDK Flutter)"
