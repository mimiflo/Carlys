#!/usr/bin/env bash
# Vérification de l'infrastructure : scripts du serveur, vhosts nginx,
# compose du serveur, Dockerfile, porte de CI et garde « build once » des
# builds mobiles de production. Rejoue ce que fait
# .github/workflows/infra-ci.yml, dans le même ordre.
#
#   ./scripts/check_infra.sh
#
# Ce que chaque essai demande, et ce qui se passe sans :
#   - shellcheck, jq, gpg, python3, docker compose (le client suffit, aucun
#     démon) : requis ;
#   - nginx : l'essai des vhosts est SAUTÉ sans lui (échec en CI) ;
#   - minio et mc : la copie hors machine est SAUTÉE sans eux (échec en CI).
#     Ils se construisent par `sh infrastructure/minio/construire.sh minio|mc
#     ~/.carlys-minio`, là où api-ci et ces essais les cherchent.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "── shellcheck ──────────────────────────────────────────────────────"
# `-S warning` : les remarques de style ou d'information déjà présentes dans
# ces scripts (SC2016 sur des guillemets simples VOULUS, par exemple) ne
# bloquent pas ; un avertissement, si.
shellcheck -x -S warning \
  scripts/server/*.sh scripts/server/carlysctl scripts/server/tests/*.sh \
  scripts/ci/*.sh scripts/ci/tests/*.sh \
  infrastructure/minio/*.sh infrastructure/nginx/tests/*.sh

echo "── Dockerfile : manifestes avant sources ───────────────────────────"
python3 scripts/ci/verifier_dockerfiles.py

echo "── Porte de CI (verdict_ci.sh) ─────────────────────────────────────"
bash scripts/ci/tests/verdict_ci_test.sh

echo "── Migrations publiées (migrations_publiees.sh) ────────────────────"
bash scripts/ci/tests/migrations_publiees_test.sh

echo "── Garde « build once » de mobile-production ───────────────────────"
bash scripts/ci/tests/preuve_recette_test.sh

echo "── Compose du serveur ──────────────────────────────────────────────"
bash scripts/server/tests/compose_test.sh

echo "── Sauvegardes : avant migration, hors machine, doctor ─────────────"
bash scripts/server/tests/sauvegarde_test.sh

echo "── Supervision : clone derrière la porte, tâches quotidiennes ──────"
bash scripts/server/tests/supervision_test.sh

echo "── Vhosts nginx : journal sans jeton, compression ──────────────────"
bash infrastructure/nginx/tests/nginx_test.sh

echo ""
echo "Toutes les vérifications d'infrastructure sont passées."
