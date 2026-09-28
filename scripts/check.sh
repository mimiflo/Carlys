#!/usr/bin/env bash
# Vérification complète des projets TypeScript : à exécuter avant tout commit.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "── Migrations publiées intactes ────────────────────────────────────"
# Contre la base commune avec origin/development : ce qui y est publié ne se
# renomme, ne se supprime ni ne se modifie. Sans origin/development (poste
# sans remote, clone superficiel), le contrôle est laissé à api-ci.
if base="$(git merge-base origin/development HEAD 2> /dev/null)"; then
  scripts/ci/migrations_publiees.sh "$base"
else
  echo "origin/development introuvable ici : contrôle laissé à api-ci."
fi

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
echo "Pour Flutter : ./scripts/check_mobile.sh"
