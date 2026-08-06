#!/usr/bin/env bash
# Vérification complète des projets TypeScript : à exécuter avant tout commit.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "── Build (packages puis apps, ordre topologique) ───────────────────"
pnpm build

echo "── Formatage ───────────────────────────────────────────────────────"
pnpm format:check

echo "── Lint ────────────────────────────────────────────────────────────"
pnpm lint

echo "── Types ───────────────────────────────────────────────────────────"
pnpm typecheck

echo "── Tests ───────────────────────────────────────────────────────────"
pnpm test

echo ""
echo "Toutes les vérifications TypeScript sont passées."
echo "Pour Flutter : cd apps/mobile && flutter analyze && flutter test"
