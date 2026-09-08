# shellcheck shell=bash
# Fonctions partagées par les scripts d'exploitation du serveur dédié.
#
# POURQUOI un fichier commun. Les quatre scripts (setup, deploy, promote,
# backup) manipulent tous les mêmes objets : la racine /srv/carlys, le nom de
# projet Compose, le fichier .env d'un environnement, le journal DEPLOYED. Ces
# règles doivent être IDENTIQUES partout — promote.sh lit le DEPLOYED que
# deploy.sh écrit, backup.sh lit le .env que setup.sh a copié. Recopier la
# lecture dans quatre scripts, c'est se garantir qu'elle divergera au premier
# changement de format.
#
# Ce fichier ne s'exécute pas seul : il se source, et il ne fait AUCUN effet de
# bord au chargement (pas de vérification, pas de mkdir). Chaque script appelle
# explicitement les gardes dont il a besoin.
#
# Il suppose `set -euo pipefail` chez l'appelant.

# ── Racines et chemins ──────────────────────────────────────────────────────
# CARLYS_ROOT est une variable pour une raison précise : elle permet de jouer
# ces scripts pour de vrai, hors serveur, contre une arborescence jetable. Sur
# le serveur, on ne la définit pas.
CARLYS_ROOT="${CARLYS_ROOT:-/srv/carlys}"

# Racine du dépôt : ce fichier vit dans <dépôt>/scripts/server/.
CARLYS_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CARLYS_REPO_DIR="${CARLYS_REPO_DIR:-$(cd -- "$CARLYS_LIB_DIR/../.." && pwd -P)}"

# Le fichier compose est UNIQUE et versionné (contrat de conception). Il est
# écrit par le lot « infrastructure » ; ces scripts le consomment sans jamais
# le modifier.
CARLYS_COMPOSE_FILE="${CARLYS_COMPOSE_FILE:-$CARLYS_REPO_DIR/infrastructure/server/compose.yml}"
CARLYS_ENV_EXAMPLES_DIR="${CARLYS_ENV_EXAMPLES_DIR:-$CARLYS_REPO_DIR/infrastructure/server/env}"

# ── Registre d'images ───────────────────────────────────────────────────────
# PRÉFIXE COMPLET des images, hôte ET propriétaire : c'est la forme qu'attend
# le compose versionné (`${CARLYS_REGISTRY}/carlys-api:${CARLYS_TAG}`) et celle
# que portent les .env d'environnement. La valeur ci-dessous n'est qu'un
# défaut : les scripts la relisent dans le .env de l'environnement, qui fait
# foi.
CARLYS_REGISTRY="${CARLYS_REGISTRY:-ghcr.io/mimiflo}"

# `docker login` prend un HÔTE, pas un préfixe d'images : ghcr.io, pas
# ghcr.io/mimiflo. Le propriétaire sert d'identifiant de connexion.
registry_host()      { printf '%s' "${CARLYS_REGISTRY%%/*}"; }
registry_namespace() { printf '%s' "${CARLYS_REGISTRY#*/}"; }

# ── Sortie ──────────────────────────────────────────────────────────────────
# Les couleurs ne servent qu'un humain devant un terminal : sous cron ou dans
# un journal, elles ne seraient que du bruit illisible.
if [ -t 1 ]; then
  _c_bold=$'\033[1m'; _c_red=$'\033[31m'; _c_green=$'\033[32m'
  _c_yellow=$'\033[33m'; _c_off=$'\033[0m'
else
  _c_bold=''; _c_red=''; _c_green=''; _c_yellow=''; _c_off=''
fi

step() { printf '\n%s── %s%s\n' "$_c_bold" "$*" "$_c_off"; }
info() { printf '   %s\n' "$*"; }
ok()   { printf '   %s✓%s %s\n' "$_c_green" "$_c_off" "$*"; }
warn() { printf '   %s⚠%s %s\n' "$_c_yellow" "$_c_off" "$*" >&2; }

# die : une erreur DIT QUOI FAIRE. Un script d'exploitation se lit à 3 h du
# matin par quelqu'un qui ne l'a pas écrit.
die() {
  printf '\n%s✗ %s%s\n' "$_c_red" "$1" "$_c_off" >&2
  shift || true
  for line in "$@"; do printf '  %s\n' "$line" >&2; done
  exit 1
}

# ── Validation des arguments ────────────────────────────────────────────────
require_env_name() {
  case "${1-}" in
    staging | production) printf '%s' "$1" ;;
    *)
      die "Environnement inconnu : « ${1-} »." \
        "Valeurs acceptées : staging | production" \
        "Exemple : $(basename -- "${0}") staging a1b2c3d4e5f6"
      ;;
  esac
}

# Un sha court de 12 caractères identifie l'image (contrat : sha-<sha12>).
# On accepte aussi un sha complet — c'est ce qu'on copie depuis GitHub — et on
# le raccourcit en le DISANT, plutôt que de refuser sur un détail de longueur.
normalize_sha() {
  local raw="${1-}"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    sha-*) raw="${raw#sha-}" ;;
  esac
  if ! printf '%s' "$raw" | grep -qE '^[0-9a-f]{12,40}$'; then
    die "Sha invalide : « ${1-} »." \
      "Attendu : 12 à 40 caractères hexadécimaux (le sha du commit construit)." \
      "Les images publiées sont taguées sha-<12 premiers caractères>."
  fi
  printf '%s' "${raw:0:12}"
}

# ── Arborescence d'un environnement ─────────────────────────────────────────
env_dir()      { printf '%s/%s' "$CARLYS_ROOT" "$1"; }
env_file()     { printf '%s/%s/.env' "$CARLYS_ROOT" "$1"; }
deployed_file(){ printf '%s/%s/DEPLOYED' "$CARLYS_ROOT" "$1"; }
backups_dir()  { printf '%s/backups' "$CARLYS_ROOT"; }
ghcr_token_file() { printf '%s/ghcr.token' "$CARLYS_ROOT"; }

require_env_file() {
  local env_name="$1" file
  file="$(env_file "$env_name")"
  [ -f "$file" ] || die "Fichier d'environnement absent : $file" \
    "Le serveur n'a pas été préparé pour « $env_name »." \
    "Lancer d'abord : sudo $CARLYS_REPO_DIR/scripts/server/setup.sh" \
    "puis remplir $file (secrets, domaine, mots de passe)."
  printf '%s' "$file"
}

require_compose_file() {
  [ -f "$CARLYS_COMPOSE_FILE" ] || die \
    "Fichier compose introuvable : $CARLYS_COMPOSE_FILE" \
    "Le dépôt doit être à jour sur le serveur (git pull), ou CARLYS_COMPOSE_FILE" \
    "doit désigner le fichier compose de déploiement."
}

# Lit une valeur dans un fichier .env SANS le sourcer. Un `source` exécuterait
# le contenu du fichier : un mot de passe contenant « $( » suffirait à lancer
# du code. On lit, on ne l'interprète pas.
env_value() {
  local key="$1" file="$2" default="${3-}" line
  line="$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}=" "$file" 2>/dev/null | tail -n 1 || true)"
  if [ -z "$line" ]; then printf '%s' "$default"; return 0; fi
  line="${line#*=}"
  line="${line%$'\r'}"
  # Guillemets d'encadrement éventuels (les .env en portent souvent).
  if [ "${line#\"}" != "$line" ] && [ "${line%\"}" != "$line" ]; then
    line="${line#\"}"; line="${line%\"}"
  elif [ "${line#\'}" != "$line" ] && [ "${line%\'}" != "$line" ]; then
    line="${line#\'}"; line="${line%\'}"
  fi
  printf '%s' "$line"
}

# ── Verrou d'environnement ──────────────────────────────────────────────────
# Deux déploiements simultanés sur le MÊME environnement s'entrelaceraient :
# deux `compose up` concurrents sur les mêmes conteneurs, et surtout deux
# écritures dans DEPLOYED dont la dernière ligne cesserait de décrire ce qui
# tourne — or c'est elle que lit promote.sh et que suit le retour arrière.
#
# `-n` : on REFUSE, on ne fait pas la queue. Attendre son tour derrière un
# déploiement en cours, c'est repartir ensuite sur un sha choisi avant que
# l'autre ne bascule ; refuser tout de suite laisse l'opérateur décider.
# Le descripteur reste ouvert pour toute la vie du script : le verrou tombe
# quand le processus se termine, y compris s'il est tué.
lock_env() {
  local env_name="$1" file
  file="$(env_dir "$env_name")/.lock"
  exec {CARLYS_LOCK_FD}>>"$file" || die "Verrou impossible à ouvrir : $file"
  flock -n "$CARLYS_LOCK_FD" || die \
    "Un déploiement de « $env_name » est DÉJÀ en cours sur cette machine." \
    "Rien n'a été fait : deux déploiements simultanés se marcheraient dessus" \
    "(conteneurs concurrents, et un journal DEPLOYED qui ne décrirait plus" \
    "ce qui tourne)." \
    "Attendre qu'il se termine, puis relancer. Pour voir qui tient le verrou :" \
    "  fuser -v $file"
}

# ── Journal DEPLOYED ────────────────────────────────────────────────────────
# Format : une ligne par événement, la DERNIÈRE fait foi.
#   <sha12>  <date UTC ISO 8601>  <opérateur>  <événement>
# Append-only : l'historique d'un environnement de production est une trace
# d'exploitation, pas un fichier de configuration qu'on écrase.
deployed_current() {
  local file
  file="$(deployed_file "$1")"
  [ -f "$file" ] || { printf ''; return 0; }
  grep -vE '^[[:space:]]*(#|$)' "$file" 2>/dev/null | tail -n 1 | awk '{print $1}' || printf ''
}

deployed_operator() {
  printf '%s@%s' "${CARLYS_OPERATOR:-${SUDO_USER:-${USER:-$(id -un)}}}" "$(hostname -s 2>/dev/null || echo inconnu)"
}

deployed_append() {
  local env_name="$1" sha="$2" event="$3" file
  file="$(deployed_file "$env_name")"
  if [ ! -f "$file" ]; then
    {
      printf '# Historique des déploiements — tenu par scripts/server/deploy.sh.\n'
      printf '# <sha12>  <date UTC>  <opérateur>  <événement>\n'
      printf '# La DERNIÈRE ligne non commentée désigne ce qui tourne.\n'
    } > "$file"
  fi
  printf '%s  %s  %s  %s\n' \
    "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(deployed_operator)" "$event" >> "$file"
}

# ── Compose ─────────────────────────────────────────────────────────────────
# Le nom de projet isole les deux environnements (réseaux, volumes, conteneurs)
# sur le même hôte. Il vient du .env s'il y est, sinon du contrat.
compose_project() {
  local env_name="$1" file="$2"
  env_value COMPOSE_PROJECT_NAME "$file" "carlys_${env_name}"
}

# `dc <env> <fichier .env> <arguments compose…>`
#
# --profile <env> : mailpit n'existe qu'en staging (profil compose « staging »
# au contrat). En production le profil ne sélectionne rien, ce qui est
# exactement le comportement voulu — une seule ligne, pas de branche.
dc() {
  local env_name="$1" file="$2"; shift 2
  docker compose \
    --project-name "$(compose_project "$env_name" "$file")" \
    --env-file "$file" \
    --file "$CARLYS_COMPOSE_FILE" \
    --profile "$env_name" \
    "$@"
}

# ── Attente bornée d'un point HTTP ──────────────────────────────────────────
# BORNÉE est le mot important : une boucle infinie sur un service qui ne
# démarrera jamais bloque le déploiement au lieu de déclencher le retour
# arrière. Retourne 0 si 200 obtenu, 1 sinon.
wait_http_200() {
  local url="$1" tries="$2" delay="$3" label="$4" code=''
  printf '   attente de %s ' "$label"
  local i=0
  while [ "$i" -lt "$tries" ]; do
    code="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$url" 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
      printf ' %s✓%s (%s)\n' "$_c_green" "$_c_off" "$url"
      return 0
    fi
    printf '.'
    i=$((i + 1))
    sleep "$delay"
  done
  printf ' %s✗%s\n' "$_c_red" "$_c_off"
  printf '   %s ne répond pas 200 après %s tentatives (dernier code : %s)\n' \
    "$url" "$tries" "${code:-aucune réponse}" >&2
  return 1
}

# ── Outils requis ───────────────────────────────────────────────────────────
require_commands() {
  local missing=()
  for cmd in "$@"; do command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd"); done
  [ "${#missing[@]}" -eq 0 ] || die \
    "Commande(s) absente(s) : ${missing[*]}" \
    "Sur un serveur préparé par scripts/server/setup.sh, elles sont installées." \
    "Sinon : sudo apt-get install -y ${missing[*]}"
}

# ── Connexion au registre ───────────────────────────────────────────────────
# Le jeton vit dans /srv/carlys/ghcr.token, en 600, JAMAIS dans un .env : un
# .env est lu par des conteneurs, monté, recopié, affiché dans un `compose
# config`. Un PAT n'a rien à y faire.
ghcr_login() {
  local file token
  file="$(ghcr_token_file)"
  [ -f "$file" ] || die "Jeton de registre absent : $file" \
    "Créer un PAT GitHub avec la portée read:packages, puis :" \
    "  printf '%s' '<le jeton>' | sudo tee $file >/dev/null" \
    "  sudo chmod 600 $file"
  token="$(tr -d '\r\n' < "$file")"
  [ -n "$token" ] || die "Jeton de registre vide : $file" \
    "Le fichier existe mais ne contient rien. Y coller le PAT read:packages :" \
    "  printf '%s' '<le jeton>' | sudo tee $file >/dev/null"
  printf '%s' "$token" \
    | docker login "$(registry_host)" --username "${CARLYS_REGISTRY_USER:-$(registry_namespace)}" --password-stdin \
    || die "Connexion à $(registry_host) refusée." \
      "Vérifier que le jeton de $file est valide et porte read:packages," \
      "et que $(registry_namespace) est bien le propriétaire des paquets."
}

# ── Noms d'images (contrat de conception) ───────────────────────────────────
# La règle du suffixe -prod ne s'écrit qu'ICI : l'admin de production porte la
# garde légale armée, celui de recette non. C'est la seule différence d'images
# entre les deux environnements — et le compose versionné l'exprime par
# CARLYS_ADMIN_TAG_SUFFIX, que deploy.sh exporte à partir de cette fonction.
admin_tag_suffix() {
  if [ "$1" = production ]; then printf '%s' '-prod'; else printf '%s' ''; fi
}
image_api()     { printf '%s/carlys-api:sha-%s' "$CARLYS_REGISTRY" "$1"; }
image_migrate() { printf '%s/carlys-api-migrate:sha-%s' "$CARLYS_REGISTRY" "$1"; }
image_admin()   { printf '%s/carlys-admin:sha-%s%s' "$CARLYS_REGISTRY" "$1" "$(admin_tag_suffix "$2")"; }

# Ports publiés sur la boucle locale (contrat de conception). Le .env peut les
# redéfinir ; les défauts ci-dessous sont ceux du contrat, pour que le script
# fonctionne même si le .env ne les nomme pas.
api_host_port() {
  local env_name="$1" file="$2" fallback=3000
  [ "$env_name" = staging ] && fallback=3100
  env_value CARLYS_API_HOST_PORT "$file" "$fallback"
}
admin_host_port() {
  local env_name="$1" file="$2" fallback=3001
  [ "$env_name" = staging ] && fallback=3101
  env_value CARLYS_ADMIN_HOST_PORT "$file" "$fallback"
}
