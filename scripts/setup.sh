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

echo "── Hooks git (remise à niveau automatique après pull) ──────────────"
# core.hooksPath est LOCAL au clone : rien n'est imposé à qui ne lance pas
# ce script. Les hooks eux-mêmes sont versionnés dans scripts/githooks/.
git config core.hooksPath scripts/githooks
chmod +x scripts/githooks/* scripts/after_update.sh 2>/dev/null || true
echo "  après chaque pull, le poste se remet à niveau tout seul"

echo "── Installation des dépendances ────────────────────────────────────"
pnpm install

echo "── Build des packages partagés ─────────────────────────────────────"
pnpm --filter "./packages/**" build

echo "── Infrastructure Docker (PostgreSQL, Redis, Mailpit, MinIO) ───────"
docker compose up -d

echo "── Client Prisma ───────────────────────────────────────────────────"
pnpm prisma:generate

echo "── Migrations et données de référence ──────────────────────────────"
# CE BLOC MANQUAIT, et son absence se voyait au premier lancement : rien ne
# crée le schéma à part `prisma migrate`. `01-init.sql`, monté dans
# /docker-entrypoint-initdb.d, ne pose que des extensions et la base de test ;
# l'API, elle, ne migre JAMAIS au démarrage (règle du dépôt : `migrate deploy`
# précède la bascule du trafic, il ne vit pas dans l'entrypoint du conteneur).
# Un poste neuf terminait donc l'installation sur une base SANS UNE SEULE
# TABLE, et `pnpm dev` — la commande proposée juste en dessous — rendait une
# erreur Prisma à la première requête.
#
# Un conteneur démarré n'est pas une base prête : on attend qu'elle accepte
# une connexion, comme le fait déjà dev_up.sh, sinon la migration échoue sur
# une course de démarrage.
printf '  attente de PostgreSQL'
PRETE=0
for _ in $(seq 1 30); do
  if docker compose exec -T postgres pg_isready -q 2>/dev/null; then
    PRETE=1; printf ' — prête\n'; break
  fi
  printf '.'; sleep 2
done
if [ "$PRETE" -eq 1 ]; then
  pnpm prisma:migrate
  pnpm prisma:seed
else
  printf '\n'
  echo "  ⚠ PostgreSQL ne répond pas après 60 s : migrations NON jouées."
  echo "    Une fois la base démarrée, reprendre à la main :"
  echo "        pnpm prisma:migrate && pnpm prisma:seed"
fi

echo ""
echo "Terminé. Prochaines commandes utiles :"
echo "  pnpm dev            # API (3000) + Admin (3001)"
echo "  pnpm test           # tests de tous les projets"
echo "  ./scripts/bootstrap_mobile.sh   # app Flutter (nécessite le SDK Flutter)"
