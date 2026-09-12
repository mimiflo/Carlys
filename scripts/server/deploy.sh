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
#   4. CATALOGUE D'EXERCICES chargé juste après, toujours avant la bascule, et
#      pour la même raison que la migration : il est LIVRÉ AVEC LE CODE (il vit
#      dans l'image de l'API), donc la version qui prend le trafic doit trouver
#      le contenu de sa propre livraison, pas celui de la précédente. Échec
#      ⇒ ARRÊT au même titre : une bibliothèque d'exercices vide ou périmée est
#      un produit cassé, et l'ancienne version sert encore, elle, un catalogue
#      cohérent. C'est aussi ce qui rend l'opération AUTOMATIQUE : les trois
#      chemins de déploiement — mise à jour automatique, promote.sh, carlysctl
#      deploy — passent tous par ici, personne n'a plus rien à taper ;
#   5. bascule, puis attente BORNÉE de la santé — /health/ready de l'API ET la
#      page d'accueil de l'admin — bornée, sinon un service mort bloque le
#      script au lieu de déclencher le retour arrière ;
#   6. santé absente ⇒ retour au sha précédent lu dans DEPLOYED, contrôlé par
#      la MÊME règle : un retour arrière qui ne vérifie que l'API peut se
#      déclarer réussi avec une admin en panne ;
#   7. succès ⇒ le nouveau sha est inscrit dans DEPLOYED (sha, date, opérateur).
#
# CE QUE LE RETOUR ARRIÈRE NE FAIT PAS. Il restaure le CODE, jamais le SCHÉMA :
# Prisma n'a pas de migration descendante, et rejouer une migration à l'envers
# sur des données de production est plus dangereux que le problème qu'on
# soigne. Corollaire à tenir : toute migration doit être compatible avec la
# version précédente du code (ajout de colonne nullable, jamais de suppression
# dans le même déploiement que le code qui cesse de l'utiliser).
#
# Le CATALOGUE tombe sous LA MÊME CONTRAINTE, et il faut la dire en toutes
# lettres : un retour arrière ne le rembobine pas, et il est chargé pendant que
# la version PRÉCÉDENTE sert encore le trafic. Le cas ordinaire est sans
# danger — le chargement ajoute et met à jour des lignes, il n'en supprime
# aucune, et un exercice de plus reste un exercice pour le code d'avant. Le cas
# qui casse est précis : un exercice qui utiliserait une valeur d'énumération
# introduite par la migration du même déploiement ; le client Prisma précédent
# ne sait pas la lire. La discipline est donc celle du schéma, transposée — la
# valeur d'énumération à un déploiement, le contenu qui s'en sert au suivant.
#
# Une interruption en cours de chargement laisse, elle, un catalogue plus
# COURT, jamais incohérent : chaque exercice est écrit entier, et la relance
# complète le reste.
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
# Chargement du catalogue : « oui » par défaut, c'est-à-dire à chaque
# déploiement. La porte de sortie existe pour un cas précis — rétablir le
# service au plus court quand on sait le catalogue déjà à jour — et pas pour
# s'habituer à la pousser : la laisser à « non » ramènerait la bibliothèque
# d'exercices périmée que cette étape existe pour empêcher.
DEPLOY_CATALOG="${CARLYS_DEPLOY_CATALOG:-oui}"

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
  CARLYS_DEPLOY_CATALOG « non » saute le chargement du catalogue (défaut oui)
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
ADMIN_PORT="$(admin_host_port "$ENV_NAME" "$ENV_FILE")"
ADMIN_URL="http://127.0.0.1:${ADMIN_PORT}/"

# L'API tourne en N exemplaires sur des ports attribués par Docker : il n'y a
# plus « le » port de l'API, il y a la liste de ceux qui écoutent, et elle n'est
# connue qu'APRÈS la bascule. La santé se vérifie donc exemplaire par
# exemplaire (voir sante_api ci-dessous).
API_REPLICAS="$(api_replicas_wanted "$ENV_NAME" "$ENV_FILE")"
API_CAPACITY="$(api_port_capacity "$ENV_NAME" "$ENV_FILE")"

# Refuser AVANT d'appeler Compose. Mesuré : au-delà de la plage, Docker échoue
# en cours de route (« all ports are allocated ») après avoir démarré une
# partie des exemplaires — la pile reste à moitié mise à l'échelle et
# l'ancienne version ne sert plus seule.
[ "$API_REPLICAS" -ge 1 ] || die \
  "CARLYS_API_REPLICAS vaut « $API_REPLICAS » : il en faut au moins 1." \
  "Fichier : $ENV_FILE"
[ "$API_REPLICAS" -le "$API_CAPACITY" ] || die \
  "CARLYS_API_REPLICAS=$API_REPLICAS dépasse la plage de ports réservée à l'API ($API_CAPACITY port(s))." \
  "Rien n'a été déployé." \
  "Soit réduire CARLYS_API_REPLICAS, soit élargir la plage dans $ENV_FILE :" \
  "  CARLYS_API_HOST_PORT=$(api_host_port "$ENV_NAME" "$ENV_FILE")" \
  "  CARLYS_API_HOST_PORT_LAST=$(api_host_port_last "$ENV_NAME" "$ENV_FILE")" \
  "En élargissant, vérifier qu'aucun autre service n'occupe les ports ajoutés" \
  "(l'admin est sur $ADMIN_PORT)."

# `sante_api <tentatives>` — attend /health/ready sur CHAQUE exemplaire en vie.
#
# Sur chacun, pas sur un seul : un déploiement où deux exemplaires sur trois
# répondent est un déploiement raté, et le contrôler à travers Nginx ne le
# verrait pas — l'équilibrage masquerait l'exemplaire mort derrière ceux qui
# répondent, jusqu'à ce que `max_fails` le sorte, c'est-à-dire après avoir servi
# des erreurs à de vrais utilisateurs.
sante_api() {
  local tries="$1" ports=() port
  mapfile -t ports < <(api_replica_ports "$ENV_NAME" "$ENV_FILE")
  if [ "${#ports[@]}" -eq 0 ]; then
    warn "aucun exemplaire d'API en marche"
    return 1
  fi
  info "exemplaires d'API : ${#ports[@]} (ports ${ports[*]})"
  for port in "${ports[@]}"; do
    wait_http_200 "http://127.0.0.1:${port}/health/ready" "$tries" "$HEALTH_DELAY" \
      "l'API sur $port (/health/ready)" || return 1
  done
  return 0
}

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
info "exemplaires API : $API_REPLICAS (plage de $API_CAPACITY port(s))"

# ── 1. Registre : connexion puis pull des trois images ──────────────────────
# Rien n'a encore bougé : c'est le bon moment pour échouer.
step "1/7 Connexion au registre"
ghcr_login
ok "connecté à $CARLYS_REGISTRY"

step "2/7 Récupération des images (sha-$SHA)"
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
step "3/7 Socle de données (postgres, redis)"
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
step "4/7 Migrations Prisma (tâche ponctuelle)"
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

# ── 4. Catalogue d'exercices — AVANT la bascule aussi ──────────────────────
# Le schéma vient d'être migré ; le CONTENU livré avec ce sha se charge
# maintenant, pour que la version qui prend le trafic à l'étape suivante
# trouve son propre catalogue, pas celui de la précédente.
#
# La commande vit dans l'IMAGE de ce sha (voir catalogue_charger dans
# _common.sh) : c'est donc bien la description du catalogue publiée avec ce
# commit qui est projetée, jamais une copie côté serveur.
#
# Rejoué à CHAQUE déploiement, y compris quand le catalogue n'a pas bougé —
# l'opération est idempotente (mise à jour par slug, identifiants de médias
# déterministes) et se compte en secondes, quand le déploiement se compte en
# minutes. Le test « le catalogue a-t-il changé ? » coûterait plus cher en
# complexité qu'il ne ferait gagner, et se tromperait un jour.
step "5/7 Catalogue d'exercices"
if [ "$DEPLOY_CATALOG" != oui ]; then
  warn "étape sautée : CARLYS_DEPLOY_CATALOG=$DEPLOY_CATALOG"
  info "La bibliothèque d'exercices reste telle qu'elle est en base."
  info "Pour la charger plus tard : carlysctl catalog-seed $ENV_NAME"
elif ! catalogue_commande_presente "$ENV_NAME" "$ENV_FILE"; then
  # Le cas normal d'un retour arrière ou d'une promotion de vieux sha : cette
  # image est antérieure à la commande. Ce n'est pas une panne — le catalogue
  # déjà en base reste servi — et faire échouer le déploiement pour autant
  # empêcherait précisément de revenir à une version saine.
  warn "l'image sha-$SHA ne porte pas dist/cli/catalog-seed : catalogue laissé en l'état."
  info "Image antérieure à cette commande (retour arrière, promotion d'un ancien sha)."
elif ! catalogue_charger "$ENV_NAME" "$ENV_FILE"; then
  die "Le chargement du catalogue a échoué — DÉPLOIEMENT INTERROMPU." \
    "RIEN n'a été basculé : api et admin tournent toujours sur ${PREVIOUS_SHA:-leur version précédente}," \
    "et servent le catalogue qu'ils servaient déjà." \
    "Le message ci-dessus dit lequel des deux étages a lâché : les textes" \
    "(PostgreSQL) ou les photos (MinIO, le plus fréquent)." \
    "Une fois la cause corrigée, redéployer suffit — l'étape est idempotente." \
    "Pour la rejouer seule, sans redéployer :" \
    "  carlysctl catalog-seed $ENV_NAME" \
    "Pour basculer SANS le catalogue (il reste alors celui d'avant) :" \
    "  CARLYS_DEPLOY_CATALOG=non carlysctl deploy $ENV_NAME $SHA"
else
  ok "catalogue à jour"
fi

# ── 5. Bascule ─────────────────────────────────────────────────────────────
step "6/7 Bascule (compose up -d)"
if ! dc "$ENV_NAME" "$ENV_FILE" up -d; then
  # Compose a refusé de démarrer la pile. Le schéma est déjà migré (migration
  # compatible avec la version précédente : c'est la contrainte annoncée en
  # tête de fichier), donc revenir au sha précédent est licite.
  warn "compose up a échoué."
  if [ -n "$PREVIOUS_SHA" ]; then
    export_tags "$PREVIOUS_SHA"
    dc "$ENV_NAME" "$ENV_FILE" up -d || true
    env_set_tag "$ENV_FILE" "sha-$PREVIOUS_SHA"
    deployed_append "$ENV_NAME" "$PREVIOUS_SHA" "retour-arrière-depuis-$SHA(compose)"
  fi
  die "Bascule impossible : docker compose n'a pas démarré la pile." \
    "Diagnostic : docker compose -p $PROJECT --env-file $ENV_FILE -f $CARLYS_COMPOSE_FILE ps" \
    "             docker compose -p $PROJECT logs --tail 100"
fi
ok "conteneurs démarrés sur sha-$SHA"

# ── 6. Santé, en boucle BORNÉE ─────────────────────────────────────────────
step "7/7 Vérification de santé"
healthy=1
sante_api "$HEALTH_TRIES" || healthy=0
# L'admin sert AUSSI les pages publiques du produit (/verify-email,
# /reset-password, /privacy…). Une admin morte, c'est le lien de vérification
# d'adresse mort : elle fait partie de la bascule, pas d'un décor.
if [ "$healthy" -eq 1 ]; then
  wait_http_200 "$ADMIN_URL" "$HEALTH_TRIES" "$HEALTH_DELAY" "l'admin (/)" || healthy=0
fi

if [ "$healthy" -eq 1 ]; then
  # Nginx apprend où écoutent les exemplaires. AVANT d'inscrire le succès :
  # tant que l'amont n'a pas été rechargé, le trafic va encore aux ports de la
  # version précédente — c'est-à-dire à des ports que plus personne n'écoute
  # dès que Compose a recréé les conteneurs. Un déploiement « réussi » qui
  # laisserait Nginx sur l'ancienne liste rendrait 502 à tout le monde.
  step "Amont Nginx"
  nginx_apply_upstream "$ENV_NAME" "$ENV_FILE" || warn \
    "l'amont Nginx n'a pas pu être mis à jour — les conteneurs sont sains, mais Nginx peut encore pointer ailleurs."

  # Le .env apprend ce qui tourne : sans cela, le `docker compose up -d`
  # documenté en tête de compose.yml relirait `sha-CHANGE_MOI_SHA12`.
  env_set_tag "$ENV_FILE" "sha-$SHA"
  deployed_append "$ENV_NAME" "$SHA" "deploy"
  printf '\n%s✓ %s déployé sur sha-%s%s\n' "$_c_green" "$ENV_NAME" "$SHA" "$_c_off"
  info "journal : $(deployed_file "$ENV_NAME")"
  dc "$ENV_NAME" "$ENV_FILE" ps || true
  exit 0
fi

# ── 7. Retour arrière ──────────────────────────────────────────────────────
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
sante_api "$ROLLBACK_TRIES" || restored=0
if [ "$restored" -eq 1 ]; then
  wait_http_200 "$ADMIN_URL" "$ROLLBACK_TRIES" "$HEALTH_DELAY" "l'admin restaurée (/)" || restored=0
fi

if [ "$restored" -eq 1 ]; then
  # Le retour arrière a recréé les conteneurs : leurs ports ont changé, donc
  # l'amont Nginx aussi. Le régénérer fait partie de la restauration, sans quoi
  # on aurait rétabli les conteneurs sans rétablir le service.
  nginx_apply_upstream "$ENV_NAME" "$ENV_FILE" || warn \
    "l'amont Nginx n'a pas pu être mis à jour après le retour arrière."

  # On inscrit le retour arrière : la dernière ligne de DEPLOYED doit toujours
  # décrire CE QUI TOURNE. Elle porte de nouveau le sha précédent — le fichier
  # reste lisible par promote.sh, et l'historique garde la trace de la tentative.
  env_set_tag "$ENV_FILE" "sha-$PREVIOUS_SHA"
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
