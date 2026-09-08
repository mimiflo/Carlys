#!/usr/bin/env bash
# Déploie un sha donné dans un environnement du serveur dédié.
#
#     scripts/server/deploy.sh <staging|production> <sha>
#
# POURQUOI CE SCRIPT EXISTE, ET POURQUOI DANS CET ORDRE
#
# Un déploiement se juge sur son chemin d'ÉCHEC. Le chemin nominal, n'importe
# quelle suite de `docker compose up` le couvre ; ce qui coûte cher, c'est
# l'environnement laissé à moitié basculé quand une migration casse ou quand la
# nouvelle image ne démarre pas. L'ordre ci-dessous n'a donc rien d'esthétique :
#
#   1. pull des TROIS images AVANT de toucher à quoi que ce soit — un registre
#      injoignable ou un sha inexistant doit échouer pendant que l'ancienne
#      version sert encore le trafic ;
#   2. migration en tâche PONCTUELLE, jamais au démarrage du conteneur
#      (règle du dépôt, infrastructure/deployment/README.md) : un redémarrage
#      ou une mise à l'échelle ne doit pas modifier le schéma ;
#   3. échec de la migration ⇒ ARRÊT, api et admin n'ont pas été touchés ;
#   4. bascule, puis attente BORNÉE de la santé — /health/ready de l'API ET la
#      page d'accueil de l'admin — bornée, sinon un service mort bloque le
#      script au lieu de déclencher le retour arrière ;
#   5. santé absente ⇒ retour au sha précédent lu dans DEPLOYED, contrôlé par
#      la MÊME règle : un retour arrière qui ne vérifie que l'API peut se
#      déclarer réussi avec une admin en panne ;
#   6. succès ⇒ le nouveau sha est inscrit dans DEPLOYED (sha, date, opérateur).
#
# CE QUE LE RETOUR ARRIÈRE NE FAIT PAS. Il restaure le CODE, jamais le SCHÉMA :
# Prisma n'a pas de migration descendante, et rejouer une migration à l'envers
# sur des données de production est plus dangereux que le problème qu'on
# soigne. Corollaire à tenir : toute migration doit être compatible avec la
# version précédente du code (ajout de colonne nullable, jamais de suppression
# dans le même déploiement que le code qui cesse de l'utiliser).
#
# PREMIER DÉPLOIEMENT. Si DEPLOYED est vide, il n'y a pas de sha précédent :
# aucun retour arrière n'est possible, et il n'y a rien à restaurer puisque
# rien ne servait le trafic. Le script le dit, laisse la pile debout pour
# qu'on puisse lire les journaux, n'écrit PAS DEPLOYED, et sort en erreur.
set -euo pipefail

# shellcheck source=scripts/server/_common.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/_common.sh"

# ── Réglages (surchargables pour un serveur lent ou un essai) ───────────────
HEALTH_TRIES="${CARLYS_HEALTH_TRIES:-60}"      # 60 × 2 s = 2 min
HEALTH_DELAY="${CARLYS_HEALTH_DELAY:-2}"
ROLLBACK_TRIES="${CARLYS_ROLLBACK_TRIES:-45}"  # le sha précédent a déjà démarré une fois
# Services de données : ils doivent être debout AVANT la migration, et ils ne
# font pas partie de la bascule (les démarrer n'expose aucune nouvelle version
# au trafic).
DATA_SERVICES="${CARLYS_DATA_SERVICES:-postgres redis}"

usage() {
  cat >&2 <<'FIN'
Usage : deploy.sh <staging|production> <sha>

  <sha>   sha du commit construit (12 à 40 caractères hexadécimaux).
          Les images sont taguées sha-<12 premiers caractères>.

Exemples :
  scripts/server/deploy.sh staging a1b2c3d4e5f6
  scripts/server/deploy.sh production a1b2c3d4e5f6   # préférer promote.sh

Variables utiles :
  CARLYS_ROOT           racine des données (défaut /srv/carlys)
  CARLYS_HEALTH_TRIES   tentatives d'attente de /health/ready (défaut 60)
  CARLYS_HEALTH_DELAY   secondes entre deux tentatives (défaut 2)
FIN
  exit 2
}

[ "$#" -eq 2 ] || usage

ENV_NAME="$(require_env_name "${1-}")"
SHA="$(normalize_sha "${2-}")"
[ "$SHA" = "$(printf '%s' "${2-}" | tr '[:upper:]' '[:lower:]')" ] \
  || info "Sha raccourci à 12 caractères : $SHA"

require_commands docker curl flock
require_compose_file
ENV_FILE="$(require_env_file "$ENV_NAME")"
# Verrou AVANT tout : un second déploiement doit repartir sans avoir touché au
# registre, aux images ni au journal. Le répertoire de l'environnement existe,
# require_env_file vient de le prouver.
lock_env "$ENV_NAME"
# Le .env de l'environnement fait foi sur le registre : c'est lui que le
# compose versionné interpole. On ne lui impose pas la valeur du script.
CARLYS_REGISTRY="$(env_value CARLYS_REGISTRY "$ENV_FILE" "$CARLYS_REGISTRY")"
PROJECT="$(compose_project "$ENV_NAME" "$ENV_FILE")"
API_PORT="$(api_host_port "$ENV_NAME" "$ENV_FILE")"
ADMIN_PORT="$(admin_host_port "$ENV_NAME" "$ENV_FILE")"
API_HEALTH_URL="http://127.0.0.1:${API_PORT}/health/ready"
ADMIN_URL="http://127.0.0.1:${ADMIN_PORT}/"

PREVIOUS_SHA="$(deployed_current "$ENV_NAME")"

# Les variables que le fichier compose interpole. Elles sont EXPORTÉES : pour
# Compose, l'environnement du shell l'emporte sur --env-file, ce qui permet de
# déployer un sha sans jamais réécrire le .env de l'environnement.
#
# CARLYS_ADMIN_TAG_SUFFIX est posé ICI plutôt que laissé au .env : le suffixe
# -prod n'est pas un réglage d'exploitation, c'est une conséquence de
# l'environnement visé. Le déduire de l'argument de deploy.sh supprime la
# faute la plus coûteuse — un .env de production dont le suffixe aurait été
# effacé déploierait l'image de RECETTE, garde légale désarmée, sans que rien
# ne proteste.
#
# CARLYS_ENV_FILE est exporté pour la même raison : le compose s'en sert comme
# `env_file`, et la seule valeur juste est le chemin que deploy.sh vient
# réellement d'ouvrir.
export_tags() {
  local sha="$1"
  export CARLYS_REGISTRY
  export CARLYS_ENV_FILE="$ENV_FILE"
  export CARLYS_TAG="sha-${sha}"
  export CARLYS_ADMIN_TAG_SUFFIX; CARLYS_ADMIN_TAG_SUFFIX="$(admin_tag_suffix "$ENV_NAME")"
}

printf '%s\n' "$_c_bold"
printf 'Déploiement Carlys — %s\n' "$ENV_NAME"
printf '%s\n' "$_c_off"
info "sha             : $SHA"
info "sha précédent   : ${PREVIOUS_SHA:-aucun (premier déploiement)}"
info "projet compose  : $PROJECT"
info "fichier .env    : $ENV_FILE"
info "santé attendue  : $API_HEALTH_URL"

# ── 1. Registre : connexion puis pull des trois images ──────────────────────
# Rien n'a encore bougé : c'est le bon moment pour échouer.
step "1/6 Connexion au registre"
ghcr_login
ok "connecté à $CARLYS_REGISTRY"

step "2/6 Récupération des images (sha-$SHA)"
IMG_API="$(image_api "$SHA")"
IMG_MIGRATE="$(image_migrate "$SHA")"
IMG_ADMIN="$(image_admin "$SHA" "$ENV_NAME")"
for image in "$IMG_API" "$IMG_MIGRATE" "$IMG_ADMIN"; do
  info "pull $image"
  docker pull --quiet "$image" >/dev/null || die \
    "Image introuvable ou registre injoignable : $image" \
    "Rien n'a été déployé : l'environnement tourne toujours sur ${PREVIOUS_SHA:-son état précédent}." \
    "Vérifier que le workflow d'images a bien publié ce sha," \
    "et pour la production que l'image admin -prod existe (voir promote.sh)."
done
ok "trois images présentes localement"

# ── 2. Socle de données debout (préalable à la migration) ───────────────────
# Démarrer postgres et redis n'est PAS une bascule : aucune nouvelle version
# n'est exposée au trafic. En régime établi ils tournent déjà et cette étape ne
# coûte rien ; au premier déploiement elle crée le réseau et le volume dont la
# migration a besoin.
step "3/6 Socle de données (postgres, redis)"
export_tags "$SHA"
# shellcheck disable=SC2086 # DATA_SERVICES est une liste de services, volontairement découpée
dc "$ENV_NAME" "$ENV_FILE" up -d $DATA_SERVICES || die \
  "Impossible de démarrer le socle de données ($DATA_SERVICES)." \
  "Rien n'a été basculé. Diagnostic : docker compose -p $PROJECT logs postgres redis"

# Attendre que PostgreSQL ACCEPTE une connexion. Un conteneur démarré n'est pas
# une base prête : la migration échouerait sur un refus de connexion et on
# accuserait la migration.
pg_ready=0
for _ in $(seq 1 30); do
  if dc "$ENV_NAME" "$ENV_FILE" exec -T postgres pg_isready -q >/dev/null 2>&1; then
    pg_ready=1; break
  fi
  sleep 2
done
[ "$pg_ready" -eq 1 ] || die \
  "PostgreSQL n'accepte pas de connexion après 60 s." \
  "Rien n'a été basculé. Diagnostic : docker compose -p $PROJECT logs postgres"
ok "PostgreSQL accepte les connexions"

# ── 3. Migration — AVANT la bascule, en tâche ponctuelle ────────────────────
# Le service `migrate` du compose versionné, sous profil dédié, donc absent de
# tout `up -d`. On l'appelle plutôt que de bricoler un `docker run --network` :
# réseau, DATABASE_URL et fichier d'environnement y sont déjà décrits, et une
# seconde description finirait par diverger de la première.
#
# PAS de `--no-deps` : le `depends_on: postgres condition: service_healthy` du
# compose est la seule description de « la base est prête », et c'est elle qui
# doit faire foi. La couper reviendrait à faire reposer la migration sur
# l'attente `pg_isready` de l'étape précédente — un second avis, plus faible
# (`pg_isready` accepte une connexion, le healthcheck interroge la BASE), et
# qui divergerait du compose au premier changement.
step "4/6 Migrations Prisma (tâche ponctuelle)"
if ! dc "$ENV_NAME" "$ENV_FILE" run --rm migrate; then
  die "La migration a échoué — DÉPLOIEMENT INTERROMPU." \
    "RIEN n'a été basculé : api et admin tournent toujours sur ${PREVIOUS_SHA:-leur version précédente}." \
    "Le socle de données est debout, le schéma est resté dans l'état où la migration l'a laissé." \
    "Relire la sortie ci-dessus, corriger la migration, publier un nouveau sha." \
    "Pour rejouer la seule migration :" \
    "  CARLYS_TAG=sha-$SHA docker compose -p $PROJECT --env-file $ENV_FILE \\" \
    "    -f $CARLYS_COMPOSE_FILE run --rm migrate"
fi
ok "schéma à jour"

# ── 4. Bascule ─────────────────────────────────────────────────────────────
step "5/6 Bascule (compose up -d)"
if ! dc "$ENV_NAME" "$ENV_FILE" up -d; then
  # Compose a refusé de démarrer la pile. Le schéma est déjà migré (migration
  # compatible avec la version précédente : c'est la contrainte annoncée en
  # tête de fichier), donc revenir au sha précédent est licite.
  warn "compose up a échoué."
  if [ -n "$PREVIOUS_SHA" ]; then
    export_tags "$PREVIOUS_SHA"
    dc "$ENV_NAME" "$ENV_FILE" up -d || true
    deployed_append "$ENV_NAME" "$PREVIOUS_SHA" "retour-arrière-depuis-$SHA(compose)"
  fi
  die "Bascule impossible : docker compose n'a pas démarré la pile." \
    "Diagnostic : docker compose -p $PROJECT --env-file $ENV_FILE -f $CARLYS_COMPOSE_FILE ps" \
    "             docker compose -p $PROJECT logs --tail 100"
fi
ok "conteneurs démarrés sur sha-$SHA"

# ── 5. Santé, en boucle BORNÉE ─────────────────────────────────────────────
step "6/6 Vérification de santé"
healthy=1
wait_http_200 "$API_HEALTH_URL" "$HEALTH_TRIES" "$HEALTH_DELAY" "l'API (/health/ready)" || healthy=0
# L'admin sert AUSSI les pages publiques du produit (/verify-email,
# /reset-password, /privacy…). Une admin morte, c'est le lien de vérification
# d'adresse mort : elle fait partie de la bascule, pas d'un décor.
if [ "$healthy" -eq 1 ]; then
  wait_http_200 "$ADMIN_URL" "$HEALTH_TRIES" "$HEALTH_DELAY" "l'admin (/)" || healthy=0
fi

if [ "$healthy" -eq 1 ]; then
  deployed_append "$ENV_NAME" "$SHA" "deploy"
  printf '\n%s✓ %s déployé sur sha-%s%s\n' "$_c_green" "$ENV_NAME" "$SHA" "$_c_off"
  info "journal : $(deployed_file "$ENV_NAME")"
  dc "$ENV_NAME" "$ENV_FILE" ps || true
  exit 0
fi

# ── 6. Retour arrière ──────────────────────────────────────────────────────
printf '\n%s✗ Santé jamais obtenue sur sha-%s%s\n' "$_c_red" "$SHA" "$_c_off" >&2
info "journaux du sha fautif (100 dernières lignes) :"
dc "$ENV_NAME" "$ENV_FILE" logs --tail 100 api admin 2>&1 | sed 's/^/   | /' || true

if [ -z "$PREVIOUS_SHA" ]; then
  # Premier déploiement : rien à restaurer. Le dire, et NE PAS écrire DEPLOYED
  # — un journal qui affirmerait qu'un sha malade est déployé serait pire que
  # pas de journal du tout, puisque promote.sh le lirait.
  die "Premier déploiement de « $ENV_NAME » : aucun sha précédent, donc AUCUN retour arrière possible." \
    "DEPLOYED n'a pas été écrit : $(deployed_file "$ENV_NAME") reste vide." \
    "Aucun trafic n'a été dégradé — rien ne servait avant celui-ci." \
    "La pile est laissée DEBOUT pour le diagnostic :" \
    "  docker compose -p $PROJECT --env-file $ENV_FILE -f $CARLYS_COMPOSE_FILE logs -f" \
    "Pour tout arrêter :" \
    "  docker compose -p $PROJECT --env-file $ENV_FILE -f $CARLYS_COMPOSE_FILE down"
fi

step "Retour arrière vers sha-$PREVIOUS_SHA"
warn "le sha $SHA est abandonné ; le schéma migré n'est PAS défait (pas de migration descendante)."
export_tags "$PREVIOUS_SHA"
# Les images précédentes sont normalement encore locales. On tente quand même
# le pull (le serveur a pu être élagué), sans en faire une condition : mieux
# vaut restaurer depuis le cache local que ne pas restaurer.
docker pull --quiet "$(image_api "$PREVIOUS_SHA")" >/dev/null 2>&1 || warn "pull de l'API précédente impossible — image locale utilisée"
docker pull --quiet "$(image_admin "$PREVIOUS_SHA" "$ENV_NAME")" >/dev/null 2>&1 || warn "pull de l'admin précédente impossible — image locale utilisée"

if ! dc "$ENV_NAME" "$ENV_FILE" up -d; then
  die "RETOUR ARRIÈRE ÉCHOUÉ — intervention manuelle requise." \
    "L'environnement $ENV_NAME peut être hors service." \
    "  docker compose -p $PROJECT --env-file $ENV_FILE -f $CARLYS_COMPOSE_FILE ps" \
    "  docker compose -p $PROJECT --env-file $ENV_FILE -f $CARLYS_COMPOSE_FILE logs --tail 200" \
    "Le dernier sha connu comme sain est $PREVIOUS_SHA."
fi

# EXACTEMENT la même règle qu'à la montée : API *et* admin. Ne contrôler que
# l'API au retour, c'est pouvoir déclarer un environnement « restauré » alors
# que l'admin est en panne — donc les pages publiques avec elle (vérification
# d'adresse, réinitialisation de mot de passe, mentions légales). Un retour
# arrière qui ment sur son résultat est pire qu'un déploiement raté : personne
# ne va vérifier ce qu'un script vient de déclarer sain.
restored=1
wait_http_200 "$API_HEALTH_URL" "$ROLLBACK_TRIES" "$HEALTH_DELAY" "l'API restaurée" || restored=0
if [ "$restored" -eq 1 ]; then
  wait_http_200 "$ADMIN_URL" "$ROLLBACK_TRIES" "$HEALTH_DELAY" "l'admin restaurée (/)" || restored=0
fi

if [ "$restored" -eq 1 ]; then
  # On inscrit le retour arrière : la dernière ligne de DEPLOYED doit toujours
  # décrire CE QUI TOURNE. Elle porte de nouveau le sha précédent — le fichier
  # reste lisible par promote.sh, et l'historique garde la trace de la tentative.
  deployed_append "$ENV_NAME" "$PREVIOUS_SHA" "retour-arrière-depuis-$SHA"
  printf '\n%s⚠ %s restauré sur sha-%s (le déploiement de %s a échoué)%s\n' \
    "$_c_yellow" "$ENV_NAME" "$PREVIOUS_SHA" "$SHA" "$_c_off" >&2
  exit 1
fi

# DEPLOYED n'est PAS écrit : le sha précédent ne sert pas non plus, l'affirmer
# ferait mentir le journal.
die "RETOUR ARRIÈRE ÉCHOUÉ : le sha précédent $PREVIOUS_SHA ne rend pas la main non plus (API ou admin)." \
  "L'environnement $ENV_NAME est probablement hors service — intervention manuelle." \
  "DEPLOYED n'a pas été mis à jour : $(deployed_file "$ENV_NAME") décrit toujours le dernier état SAIN connu." \
  "Piste la plus fréquente : la migration qui vient d'être appliquée n'est pas" \
  "compatible avec le code précédent. Vérifier le schéma avant de redéployer." \
  "  docker compose -p $PROJECT --env-file $ENV_FILE -f $CARLYS_COMPOSE_FILE logs --tail 200"
