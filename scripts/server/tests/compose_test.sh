#!/usr/bin/env bash
# Tests du compose du serveur, tel que Compose le COMPREND — pas tel qu'il est
# écrit : `docker compose config` interpole les deux .env d'exemple et rend
# ce que le moteur recevrait. Aucun démon Docker n'est nécessaire.
#
#   bash scripts/server/tests/compose_test.sh
#
# Ce qui est vérifié :
#   - la recette est plafonnée en mémoire, la production non, et la base de
#     production est protégée du tueur de processus du noyau ;
#   - le tas de V8 de l'API reste sous le plafond de son conteneur ;
#   - le Redis de recette a un `--maxmemory` sous son plafond ;
#   - PostgreSQL reçoit les réglages du planificateur (SSD).
set -euo pipefail

# shellcheck source=scripts/server/tests/lib.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
DEPOT="$(cd -- "$BANC_SERVEUR/../.." && pwd -P)"
COMPOSE="${CARLYS_TEST_COMPOSE:-$DEPOT/infrastructure/server/compose.yml}"
EXEMPLES="${CARLYS_TEST_EXEMPLES:-$DEPOT/infrastructure/server/env}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! docker compose version >/dev/null 2>&1; then
  sauter "docker compose absent"
  banc_bilan
  exit $?
fi

# `rendu <env>` — le compose interpolé en JSON, avec les valeurs de l'exemple.
# Un second argument ajoute un profil : `rendu staging ollama` rend la pile
# avec le coach sur le serveur allumé, comme `dc` le fait quand le .env porte
# CARLYS_OLLAMA_REPLICAS=1.
rendu() {
  local env_name="$1" fichier="$TMP/$1.env" profils=(--profile "$1")
  [ -n "${2-}" ] && profils+=(--profile "$2")
  grep -E '^[A-Z_][A-Z0-9_]*=' "$EXEMPLES/$env_name.env.example" > "$fichier"
  CARLYS_ENV_FILE="$fichier" CARLYS_TAG=sha-000000000000 CARLYS_ADMIN_TAG_SUFFIX='' \
    docker compose --env-file "$fichier" -f "$COMPOSE" "${profils[@]}" \
    config --format json 2>"$TMP/$env_name.err"
}
champ() { jq -r "$2" <<< "$1"; }
# « 128mb » (Redis) → octets. numfmt veut « 128M ».
octets() { local v="${1^^}"; numfmt --from=iec "${v%B}"; }

echo "compose.yml — mémoire et réglages"
recette="$(rendu staging)"
production="$(rendu production)"

for service in api admin postgres redis minio; do
  verifier "recette : $service a un plafond mémoire" oui \
    "$(champ "$recette" ".services.$service.mem_limit // \"\"" | grep -qE '^[1-9][0-9]*$' && echo oui || echo non)"
  verifier "production : $service n'a pas de plafond par défaut" aucun \
    "$(champ "$production" ".services.$service.mem_limit // \"aucun\"")"
done

# Le coach sur le serveur : ABSENT tant qu'on ne l'allume pas — pas seulement
# à zéro exemplaire, sinon `up -d` tirerait quand même son image de près de
# 4 Go —, et injoignable de l'extérieur une fois allumé.
for env_name in staging production; do
  json="$([ "$env_name" = staging ] && echo "$recette" || echo "$production")"
  verifier "$env_name : ollama absent sans son profil" absent \
    "$(champ "$json" 'if .services.ollama then "présent" else "absent" end')"
done
recette_coach="$(rendu staging ollama)"
production_coach="$(rendu production ollama)"
for json in "$recette_coach" "$production_coach"; do
  verifier "ollama allumé : aucun port publié" 0 "$(champ "$json" '(.services.ollama.ports // []) | length')"
  verifier "ollama allumé : priorité processeur sous l'API" 256 "$(champ "$json" '.services.ollama.cpu_shares')"
done
verifier "recette : ollama a un plafond mémoire" oui \
  "$(champ "$recette_coach" '.services.ollama.mem_limit // ""' | grep -qE '^[1-9][0-9]*$' && echo oui || echo non)"
verifier "production : ollama n'a pas de plafond par défaut" aucun \
  "$(champ "$production_coach" '.services.ollama.mem_limit // "aucun"')"

verifier "production : la base est protégée du tueur de processus" -500 \
  "$(champ "$production" '.services.postgres.oom_score_adj // 0')"
verifier "recette : la base n'est pas privilégiée" 0 \
  "$(champ "$recette" '.services.postgres.oom_score_adj // 0')"

tas="$(champ "$recette" '.services.api.environment.NODE_OPTIONS' | sed -n 's/.*--max-old-space-size=\([0-9]*\).*/\1/p')"
plafond_api="$(champ "$recette" '.services.api.mem_limit')"
verifier "recette : le tas de V8 tient sous le plafond de l'API" oui \
  "$([ -n "$tas" ] && [ "$((tas * 1024 * 1024))" -lt "$plafond_api" ] && echo oui || echo non)"

commande_redis="$(champ "$recette" '(.services.redis.command // []) | join(" ")')"
maxmem="$(sed -n 's/.*--maxmemory \([0-9]*[kmgKMG][bB]*\).*/\1/p' <<< "$commande_redis")"
verifier "recette : Redis a un --maxmemory sous son plafond" oui \
  "$([ -n "$maxmem" ] && [ "$(octets "$maxmem")" -lt "$(champ "$recette" '.services.redis.mem_limit')" ] && echo oui || echo non)"
verifier "recette : Redis n'évince que des clés à échéance" oui \
  "$(grep -q -- '--maxmemory-policy volatile-ttl' <<< "$commande_redis" && echo oui || echo non)"

for env_name in staging production; do
  json="$recette"; [ "$env_name" = production ] && json="$production"
  commande_pg="$(champ "$json" '(.services.postgres.command // []) | join(" ")')"
  verifier "$env_name : random_page_cost=1.1 (SSD)" oui \
    "$(grep -q 'random_page_cost=1.1' <<< "$commande_pg" && echo oui || echo non)"
  verifier "$env_name : effective_io_concurrency=200" oui \
    "$(grep -q 'effective_io_concurrency=200' <<< "$commande_pg" && echo oui || echo non)"
  verifier "$env_name : effective_cache_size jamais sous le défaut de PostgreSQL" 4GB \
    "$(sed -n 's/.*effective_cache_size=\([^ ]*\).*/\1/p' <<< "$commande_pg")"
done

banc_bilan
