# shellcheck shell=bash
# Banc d'essai des scripts serveur — sans serveur, sans Docker.
#
# Un CARLYS_ROOT jetable (les scripts le prévoient : « jouer ces scripts pour
# de vrai, hors serveur, contre une arborescence jetable », _common.sh) et un
# `docker` FACTICE en tête du PATH, qui :
#   - consigne chaque appel dans $FAUX_JOURNAL, une ligne par appel ;
#   - joue le rôle de PostgreSQL (`exec … postgres sh -c … pg_dump`) selon
#     FAUX_PG_DUMP (ok | echec | vide) ;
#   - fait échouer ou réussir `run --rm migrate` selon FAUX_MIGRATE ;
#   - tient le registre : `manifest inspect <image:sha-X>` réussit, sauf si X
#     est nommé dans FAUX_IMAGES_ABSENTES (une CI rouge, ou encore en cours) ;
#   - joue les CLI de l'image API : `--entrypoint test api -f dist/cli/<cli>.js`
#     réussit sauf si <cli> est nommé dans FAUX_CLI_ABSENTS, et
#     `run … api node dist/cli/<cli> …` rend FAUX_CLI_CODE (0 par défaut) ;
#   - exécute POUR DE VRAI, avec le `sh` de l'hôte, les scripts que les
#     scripts serveur confient au conteneur mc (`--entrypoint /bin/sh
#     minio-init -c …`) : volumes `-v hôte:conteneur` et adresse
#     http://minio:9000 sont réécrits vers l'hôte. Le `mc` et le `minio`
#     appelés sont alors de vrais binaires (voir banc_binaires_minio).
#
# Source par les fichiers *_test.sh de ce dossier.

BANC_ICI="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# Lu par les fichiers de test qui sourcent celui-ci.
# shellcheck disable=SC2034
BANC_SERVEUR="$(cd -- "$BANC_ICI/.." && pwd -P)"

banc_echecs=0
banc_reussis=0
banc_sautes=0

verifier() {
  local nom="$1" attendu="$2" obtenu="$3"
  if [ "$attendu" = "$obtenu" ]; then
    banc_reussis=$((banc_reussis + 1)); printf '  ok    %s\n' "$nom"
  else
    banc_echecs=$((banc_echecs + 1)); printf '  ÉCHEC %s : attendu « %s », obtenu « %s »\n' "$nom" "$attendu" "$obtenu"
    if [ -f "${BANC_SORTIE:-/nonexistent}" ]; then sed 's/^/        | /' "$BANC_SORTIE" | tail -n 25; fi
  fi
  return 0
}

sauter() {
  banc_sautes=$((banc_sautes + 1)); printf '  SAUTÉ %s\n' "$1"
}

banc_bilan() {
  printf '\n%s réussi(s), %s échec(s), %s sauté(s)\n' "$banc_reussis" "$banc_echecs" "$banc_sautes"
  if [ "$banc_sautes" -gt 0 ] && [ "${CARLYS_TEST_EXIGER_MINIO:-non}" = oui ]; then
    echo "CARLYS_TEST_EXIGER_MINIO=oui : un essai sauté est un échec."
    return 1
  fi
  [ "$banc_echecs" -eq 0 ]
}

# `banc_preparer` — racine jetable, docker factice, deux .env. Pose BANC,
# CARLYS_ROOT, FAUX_JOURNAL, BANC_SORTIE et le PATH.
banc_preparer() {
  BANC="$(mktemp -d)"
  export CARLYS_ROOT="$BANC/srv"
  export FAUX_JOURNAL="$BANC/docker.journal"
  export BANC_SORTIE="$BANC/sortie"
  export FAUX_PG_DUMP=ok FAUX_MIGRATE=echec FAUX_SERVICES="postgres redis minio"
  export MC_CONFIG_DIR="$BANC/mc"
  mkdir -p "$BANC/bin" "$CARLYS_ROOT/staging" "$CARLYS_ROOT/production"
  : > "$FAUX_JOURNAL"
  printf 'jeton-factice' > "$CARLYS_ROOT/ghcr.token"
  local env_name port
  for env_name in staging production; do
    port=3000; [ "$env_name" = staging ] && port=3100
    cat > "$CARLYS_ROOT/$env_name/.env" <<FIN
COMPOSE_PROJECT_NAME=carlys_$env_name
CARLYS_ENV=$env_name
CARLYS_REGISTRY=ghcr.io/banc
CARLYS_TAG=sha-000000000000
POSTGRES_USER=carlys
POSTGRES_DB=carlys_$env_name
S3_BUCKET=carlys-media
CARLYS_API_HOST_PORT=$port
CARLYS_API_HOST_PORT_LAST=$((port + 19))
FIN
  done
  banc_docker_factice > "$BANC/bin/docker"
  chmod +x "$BANC/bin/docker"
  export PATH="$BANC/bin:$PATH"
}

banc_nettoyer() {
  if [ -n "${BANC_MINIO_PID:-}" ]; then kill "$BANC_MINIO_PID" 2>/dev/null || true; fi
  BANC_MINIO_PID=''
  if [ -n "${BANC:-}" ]; then rm -rf "$BANC"; fi
}

# `banc_deployer <env> <sha12>` — une ligne DEPLOYED, comme deploy.sh l'écrit.
banc_deployer() {
  printf '%s  2026-09-01T00:00:00Z  banc@banc  deploy\n' "$2" >> "$CARLYS_ROOT/$1/DEPLOYED"
}

# `banc_lancer <commande…>` — rend le code de sortie, garde la sortie.
banc_lancer() {
  local code=0
  "$@" > "$BANC_SORTIE" 2>&1 < /dev/null || code=$?
  printf '%s' "$code"
}

# Numéro de la première ligne du journal qui contient un motif (0 : absente).
banc_rang() {
  local n
  n="$(grep -n -F -- "$1" "$FAUX_JOURNAL" | head -n 1 | cut -d: -f1)"
  printf '%s' "${n:-0}"
}

# ── Vrais minio et mc, pour la copie hors machine ────────────────────────────
# Cherchés dans CARLYS_TEST_MINIO_BIN (dossier), puis ~/.carlys-minio (celui
# qu'api-ci remplit par infrastructure/minio/construire.sh), puis le PATH.
banc_binaires_minio() {
  local d
  for d in "${CARLYS_TEST_MINIO_BIN:-}" "$HOME/.carlys-minio"; do
    if [ -n "$d" ] && [ -x "$d/minio" ] && [ -x "$d/mc" ]; then
      ln -sf "$d/minio" "$BANC/bin/minio"; ln -sf "$d/mc" "$BANC/bin/mc"
      return 0
    fi
  done
  command -v minio >/dev/null 2>&1 && command -v mc >/dev/null 2>&1
}

# `banc_demarrer_minio` — un serveur MinIO local, qui tient à la fois lieu de
# MinIO de l'environnement (bucket des médias) et de stockage DISTANT.
banc_demarrer_minio() {
  local port=19400 i
  export FAUX_MINIO_URL="http://127.0.0.1:$port"
  export MINIO_ROOT_USER=banc-racine MINIO_ROOT_PASSWORD='banc/secret+de=test'
  mkdir -p "$BANC/minio-data"
  minio server "$BANC/minio-data" --address "127.0.0.1:$port" --console-address "127.0.0.1:$((port + 1))" \
    > "$BANC/minio.log" 2>&1 &
  BANC_MINIO_PID=$!
  for i in $(seq 1 40); do
    curl -fs "$FAUX_MINIO_URL/minio/health/live" >/dev/null 2>&1 && break
    sleep 0.25
    [ "$i" -lt 40 ] || { cat "$BANC/minio.log"; return 1; }
  done
  printf '%s\n%s\n' "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" | mc alias set banc "$FAUX_MINIO_URL" >/dev/null
}

# Le docker factice. Écrit sur la sortie standard.
banc_docker_factice() {
  cat <<'FAUX'
#!/usr/bin/env bash
set -uo pipefail
printf '%s\n' "$*" >> "$FAUX_JOURNAL"
case "${1-}" in
  login) cat > /dev/null; exit 0 ;;
  pull | info | image) exit 0 ;;
  manifest)
    case " ${FAUX_IMAGES_ABSENTES:-} " in *" ${3##*:sha-} "*) exit 1 ;; esac
    exit 0 ;;
  compose) shift ;;
  *) exit 0 ;;
esac
# Options globales de compose : ignorées.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --project-name | --env-file | --file | --profile | -p | -f) shift 2 ;;
    *) break ;;
  esac
done
sous="${1-}"; shift || true
case "$sous" in
  pull | up | down | logs | stop) exit 0 ;;
  # Une écriture par service, espacées, comme docker compose : le lecteur
  # qui s'arrête au premier trouvé (`grep -q`) ferme le tube avant la
  # suivante. Sans la pause, cette course ne se voyait que sous charge.
  ps) for s in $FAUX_SERVICES; do printf '%s\n' "$s"; sleep 0.05; done; exit 0 ;;
  exec)
    [ "${1-}" = -T ] && shift
    service="$1"; shift
    if [ "$service" = postgres ] && [ "${1-}" = pg_isready ]; then exit 0; fi
    if [ "$service" = postgres ] && [ "${1-}" = sh ]; then
      case "$FAUX_PG_DUMP" in
        echec) echo "pg_dump: error: connection to server failed" >&2; exit 1 ;;
        vide) echo "pas un dump"; exit 0 ;;
        *) printf 'PGDMP-banc-%s-%s\n' "${4-}" "${5-}"; exit 0 ;;
      esac
    fi
    exit 0 ;;
  run)
    volumes=(); entree=''
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --rm | -T | --no-deps | -d) shift ;;
        -v | --volume) volumes+=("$2"); shift 2 ;;
        -e | --env) shift 2 ;;
        --entrypoint) entree="$2"; shift 2 ;;
        *) break ;;
      esac
    done
    service="$1"; shift
    case "$service" in
      migrate) [ "$FAUX_MIGRATE" = ok ]; exit $? ;;
      api)
        if [ "$entree" = test ]; then
          cli="${2##*/}"
          case " ${FAUX_CLI_ABSENTS:-} " in *" ${cli%.js} "*) exit 1 ;; esac
          exit 0
        fi
        exit "${FAUX_CLI_CODE:-0}" ;;
      minio-init)
        [ "$entree" = /bin/sh ] && [ "${1-}" = -c ] || exit 0
        script="$2"; shift 2
        args=("$@")
        for v in "${volumes[@]}"; do
          hote="${v%%:*}"; reste="${v#*:}"; conteneur="${reste%%:*}"
          script="${script//"$conteneur"/"$hote"}"
          for i in "${!args[@]}"; do args[i]="${args[i]//"$conteneur"/"$hote"}"; done
        done
        script="${script//http:\/\/minio:9000/${FAUX_MINIO_URL:-http://127.0.0.1:1}}"
        exec sh -c "$script" "${args[@]}"
        ;;
      *) exit 1 ;;
    esac ;;
  *) exit 0 ;;
esac
FAUX
}
