#!/usr/bin/env bash
# Remise à niveau du poste après un pull, un checkout ou à la demande
# (`pnpm refresh`) : le poste SUIT le dépôt, personne n'a à se rappeler
# quelle commande relancer après quel changement.
#
# Appelé par les hooks git (scripts/githooks/, activés par setup.sh) avec
# les deux révisions de la mise à jour ; sans argument, tout est refait.
#
# Volontairement SANS set -e : un poste remis aux trois quarts avec des
# avertissements clairs vaut mieux qu'un hook qui claque au milieu.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

FROM="${1:-}"
TO="${2:-HEAD}"

if [ -n "$FROM" ] && git rev-parse -q --verify "$FROM^{commit}" >/dev/null 2>&1; then
  CHANGED="$(git diff --name-only "$FROM" "$TO")"
  [ -z "$CHANGED" ] && exit 0
else
  CHANGED="" # révision de départ inconnue : tout refaire
fi

# Un motif vide (tout refaire) matche tout.
touched() {
  [ -z "$CHANGED" ] || printf '%s\n' "$CHANGED" | grep -qE "$1"
}

say() { printf '\n── %s ──\n' "$1"; }

if touched '(^|/)package\.json$|^pnpm-lock\.yaml$'; then
  say "Dépendances JS"
  pnpm install || echo "⚠ pnpm install a échoué — à relancer à la main"
fi

# La cause d'erreur la plus sournoise : l'API et l'admin consomment les
# packages partagés COMPILÉS. Un pull qui les change sans rebuild donne
# des « has no exported member » qui n'orientent vers rien.
if touched '^packages/'; then
  say "Packages partagés"
  pnpm --filter "./packages/**" build || echo "⚠ build des packages échoué"
fi

if touched '^apps/api/prisma/schema\.prisma$'; then
  say "Client Prisma"
  pnpm prisma:generate || echo "⚠ prisma generate a échoué"
fi

if touched '^apps/api/prisma/migrations/'; then
  say "Migrations de base"
  pnpm prisma:migrate ||
    echo "⚠ Migration non appliquée — démarre Docker Desktop puis : pnpm prisma:migrate"
fi

if command -v flutter >/dev/null 2>&1 && [ -f apps/mobile/pubspec.yaml ]; then
  if touched '^apps/mobile/pubspec\.yaml$'; then
    say "Dépendances Flutter"
    (cd apps/mobile && flutter pub get) || echo "⚠ flutter pub get a échoué"
  fi
  # Le code engendré par Drift se régénère si ses sources ont bougé — ou
  # s'il manque tout simplement, ce qui arrive sur un clone frais et après
  # un `flutter clean`. Hors ces deux cas, build_runner est trop lent pour
  # tourner « au cas où ».
  if touched '^apps/mobile/lib/core/database/' ||
    [ ! -f apps/mobile/lib/core/database/app_database.g.dart ]; then
    say "Code engendré (Drift)"
    (cd apps/mobile && dart run build_runner build --delete-conflicting-outputs) ||
      echo "⚠ build_runner a échoué"
  fi
fi

exit 0
