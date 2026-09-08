#!/usr/bin/env bash
# Promeut en production le sha actuellement déployé en recette (staging).
#
#     scripts/server/promote.sh              # le sha courant de staging
#     scripts/server/promote.sh <sha>        # un sha choisi explicitement
#
# POURQUOI CE SCRIPT PLUTÔT QU'UN DÉPLOIEMENT AUTOMATIQUE. « Pas de
# déploiement automatique en production sans validation humaine »
# (infrastructure/deployment/README.md). Promouvoir, c'est confirmer que ce
# qu'on a vu tourner en recette est bien ce qui partira aux utilisateurs — et
# c'est le MÊME sha qui repart : on construit une fois, on déploie deux fois
# (build once). Reconstruire pour la production, c'est déployer un artefact
# que personne n'a testé.
#
# LA GARDE LÉGALE N'EST PAS UNE PANNE. L'image admin de production porte le
# tag sha-<sha>-prod, produite par un workflow dédié qui ÉCHOUE tant que
# docs/legal/*.md contiennent des marqueurs « [À COMPLÉTER : … ] » : mentions
# légales, adresse de contact, délais de conservation. Tant que ces textes ne
# sont pas écrits, l'image -prod n'existe pas et ce script refuse — c'est le
# comportement voulu. Les magasins d'applications exigent une URL de politique
# de confidentialité valide ; publier une page portant « [À COMPLÉTER] » se
# paie en refus de publication, pas en avertissement.
set -euo pipefail

# shellcheck source=scripts/server/_common.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/_common.sh"

usage() {
  cat >&2 <<'FIN'
Usage : promote.sh [sha]

  Sans argument : promeut le sha inscrit dans /srv/carlys/staging/DEPLOYED.
  Avec un sha   : promeut ce sha (12 à 40 caractères hexadécimaux).

Le script vérifie que l'image admin de PRODUCTION (sha-<sha>-prod) existe dans
le registre, demande confirmation, puis appelle deploy.sh production <sha>.
FIN
  exit 2
}

[ "$#" -le 1 ] || usage
case "${1-}" in -h | --help | help) usage ;; esac

require_commands docker curl
require_compose_file
# La production doit être préparée AVANT qu'on interroge le registre : mieux
# vaut échouer sur un .env manquant maintenant que juste après la confirmation.
# C'est aussi lui qui fait foi sur le préfixe des images.
PRODUCTION_ENV_FILE="$(require_env_file production)"
CARLYS_REGISTRY="$(env_value CARLYS_REGISTRY "$PRODUCTION_ENV_FILE" "$CARLYS_REGISTRY")"

# ── 1. Quel sha ? ───────────────────────────────────────────────────────────
if [ -n "${1-}" ]; then
  SHA="$(normalize_sha "$1")"
  SOURCE="fourni en argument"
else
  require_env_file staging >/dev/null # garde : l'environnement doit exister
  SHA="$(deployed_current staging)"
  [ -n "$SHA" ] || die \
    "Aucun sha déployé en recette : $(deployed_file staging) est vide." \
    "Déployer d'abord en staging :" \
    "  $CARLYS_REPO_DIR/scripts/server/deploy.sh staging <sha>" \
    "ou promouvoir un sha explicitement : promote.sh <sha>"
  SHA="$(normalize_sha "$SHA")"
  SOURCE="lu dans $(deployed_file staging)"
fi

CURRENT_PROD="$(deployed_current production)"

printf '%s\n' "$_c_bold"
printf 'Promotion en production\n'
printf '%s\n' "$_c_off"
info "sha à promouvoir      : $SHA ($SOURCE)"
info "production actuelle   : ${CURRENT_PROD:-aucune (première mise en production)}"

if [ -n "$CURRENT_PROD" ] && [ "$CURRENT_PROD" = "$SHA" ]; then
  ok "la production tourne déjà sur ce sha — rien à faire."
  exit 0
fi

# ── 2. L'image de production existe-t-elle ? ────────────────────────────────
step "Vérification du registre"
ghcr_login

IMG_ADMIN_PROD="$(image_admin "$SHA" production)"
IMG_ADMIN_STAGING="$(image_admin "$SHA" staging)"

# `docker manifest inspect` interroge le registre SANS télécharger l'image :
# on veut savoir si le tag existe, pas rapatrier plusieurs centaines de Mio
# avant de découvrir qu'il manque.
manifest_exists() {
  docker manifest inspect "$1" >/dev/null 2>&1
}

if ! manifest_exists "$IMG_ADMIN_PROD"; then
  # Distinguer les deux causes change complètement ce qu'il faut faire : soit
  # le sha n'a jamais été construit (mauvais sha), soit il l'a été mais la
  # garde légale a bloqué la variante de production.
  if manifest_exists "$IMG_ADMIN_STAGING"; then
    die "L'image admin de PRODUCTION n'existe pas pour ce sha : $IMG_ADMIN_PROD" \
      "L'image de recette ($IMG_ADMIN_STAGING) existe, elle : le commit a bien" \
      "été construit, mais la variante de production n'a pas été produite." \
      "" \
      "C'est presque toujours la GARDE LÉGALE, et c'est normal : le build de" \
      "production échoue tant que docs/legal/*.md portent des marqueurs" \
      "« [À COMPLÉTER : … ] » (raison sociale, adresse de contact, délais de" \
      "conservation). Ce n'est pas une panne, c'est le filet." \
      "" \
      "Ce qu'il faut faire :" \
      "  1. compléter les marqueurs de docs/legal/*.md et pousser ;" \
      "  2. lancer le workflow de publication de l'image -prod (workflow_dispatch," \
      "     entrée : le sha $SHA) ;" \
      "  3. relancer promote.sh." \
      "" \
      "Vérifier localement ce qui manque :" \
      "  grep -rn 'À COMPLÉTER' docs/legal/"
  fi
  die "Aucune image admin publiée pour ce sha : ni $IMG_ADMIN_PROD, ni $IMG_ADMIN_STAGING." \
    "Le sha $SHA n'a probablement jamais été construit, ou le jeton du registre" \
    "n'a pas accès à ces paquets." \
    "Vérifier la liste des tags publiés côté GitHub Packages avant de réessayer."
fi
ok "image admin de production présente : $IMG_ADMIN_PROD"

# L'API et les migrations n'ont pas de variante -prod, mais elles doivent
# évidemment exister au même sha : autant le dire ici plutôt que de laisser
# deploy.sh échouer après la confirmation.
for image in "$(image_api "$SHA")" "$(image_migrate "$SHA")"; do
  manifest_exists "$image" || die \
    "Image absente du registre : $image" \
    "Les trois images doivent exister au même sha (build once)." \
    "Vérifier que le workflow d'images a bien terminé pour $SHA."
  ok "présente : $image"
done

# ── 3. Confirmation humaine ────────────────────────────────────────────────
# On demande de RECOPIER le sha, pas de taper « oui » : une frappe réflexe ne
# doit pas suffire à basculer la production. Recopier douze caractères oblige
# à regarder lequel on déploie.
step "Confirmation"
info "Vont être déployés en production :"
info "  $(image_api "$SHA")"
info "  $(image_migrate "$SHA")"
info "  $IMG_ADMIN_PROD"
if [ -n "$CURRENT_PROD" ]; then
  info "En cas d'échec de santé, retour automatique sur $CURRENT_PROD."
fi
printf '\n   Recopier le sha pour confirmer (%s), ou Entrée pour annuler : ' "$SHA"
read -r answer || answer=''
if [ "$answer" != "$SHA" ]; then
  printf '\n%s Promotion annulée — rien n'"'"'a été déployé.%s\n' "$_c_yellow" "$_c_off"
  exit 1
fi

# ── 4. Déploiement ─────────────────────────────────────────────────────────
step "Appel de deploy.sh production $SHA"
exec "$CARLYS_LIB_DIR/deploy.sh" production "$SHA"
