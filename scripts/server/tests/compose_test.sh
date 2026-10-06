#!/usr/bin/env bash
# Tests du compose du serveur, tel que Compose le COMPREND — pas tel qu'il est
# écrit : `docker compose config` interpole la configuration versionnée et
# les deux gabarits de secrets, et rend ce que le moteur recevrait. Aucun
# démon Docker n'est nécessaire.
#
#   bash scripts/server/tests/compose_test.sh
#
# Ce qui est vérifié :
#   - la recette est plafonnée en mémoire, la production non, et la base de
#     production est protégée du tueur de processus du noyau ;
#   - le tas de V8 de l'API reste sous le plafond de son conteneur ;
#   - le Redis de recette a un `--maxmemory` sous son plafond ;
#   - PostgreSQL reçoit les réglages du planificateur (SSD) ;
#   - la configuration versionnée ne porte aucun secret, le gabarit aucun
#     réglage, et chaque variable de l'API est portée par l'un des deux.
set -euo pipefail

# shellcheck source=scripts/server/tests/lib.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
DEPOT="$(cd -- "$BANC_SERVEUR/../.." && pwd -P)"
COMPOSE="${CARLYS_TEST_COMPOSE:-$DEPOT/infrastructure/server/compose.yml}"
EXEMPLES="${CARLYS_TEST_EXEMPLES:-$DEPOT/infrastructure/server/env}"
CONFIG="${CARLYS_TEST_CONFIG:-$DEPOT/infrastructure/server/config}"
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
  # Les couches de `dc` (ADR 0017) : réglages versionnés, puis secrets.
  CARLYS_CONFIG_DIR="$CONFIG" CARLYS_ENV_FILE="$fichier" CARLYS_TAG=sha-000000000000 CARLYS_ADMIN_TAG_SUFFIX='' \
    docker compose --env-file "$CONFIG/commun.conf" --env-file "$CONFIG/$env_name.conf" \
    --env-file "$fichier" -f "$COMPOSE" "${profils[@]}" \
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
done
# En production, seuls l'API (une fuite ferait swapper l'hôte, base
# comprise) et Redis (son cache croîtrait sans fin) sont bornés ; la base,
# l'admin et le stockage attendent de connaître la RAM de l'hôte.
for service in admin postgres minio; do
  verifier "production : $service n'a pas de plafond par défaut" aucun \
    "$(champ "$production" ".services.$service.mem_limit // \"aucun\"")"
done
verifier "production : chaque exemplaire de l'API est plafonné" "$(octets 768m)" \
  "$(champ "$production" '.services.api.mem_limit')"
verifier "production : le tas de V8 s'arrête sous le plafond" oui \
  "$(champ "$production" '.services.api.environment.NODE_OPTIONS' | grep -q -- '--max-old-space-size=576' && echo oui || echo non)"
verifier "postgres : requêtes lentes journalisées SANS leurs valeurs" oui \
  "$(champ "$production" '.services.postgres.command | join(" ")' | grep -q 'log_parameter_max_length=0' && echo oui || echo non)"
verifier "postgres : /dev/shm assez grand pour les requêtes parallèles" "$(octets 1g)" \
  "$(champ "$production" '.services.postgres.shm_size')"
verifier "api : le temps de finir ce qui est en vol avant SIGKILL" 30s \
  "$(champ "$production" '.services.api.stop_grace_period')"
verifier "production : Redis est plafonné" "$(octets 1g)" \
  "$(champ "$production" '.services.redis.mem_limit')"
verifier "production : Redis évince sous son plafond, jamais une clé sans échéance" oui \
  "$(champ "$production" '.services.redis.command | join(" ")' | grep -q -- '--maxmemory 512mb --maxmemory-policy volatile-lru' && echo oui || echo non)"

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
  verifier "ollama allumé : le modèle est préchargé au démarrage" true \
    "$(champ "$json" '.services.ollama.command | join(" ") | contains("ollama run \"$$CARLYS_OLLAMA_MODEL\" \"\"")')"
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
  "$(grep -q -- '--maxmemory-policy volatile-lru' <<< "$commande_redis" && echo oui || echo non)"

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

echo
echo "configuration versionnée (ADR 0017) — réglages ici, secrets au .env"

# Les clés d'un fichier, actives ou commentées (la forme d'une facultative).
cles() { sed -n 's/^[[:space:]]*#\{0,1\}[[:space:]]*\([A-Z_][A-Z0-9_]*\)=.*/\1/p' "$@" | sort -u; }
actives() { sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p' "$@" | sort -u; }
# shellcheck disable=SC1091 # chargé pour ses lecteurs de schéma, sans effet de bord
api="$(CARLYS_REPO_DIR="$DEPOT" bash -c '. "$1/scripts/server/_common.sh"; envcheck_cles_api' _ "$DEPOT")"
for env_name in staging production; do
  conf=("$CONFIG/commun.conf" "$CONFIG/$env_name.conf")
  # Le format STRICT d'abord : il rend les gardes suivantes exactes. Compose
  # accepterait aussi `export CLE=`, `CLE =…` ou une minuscule, que `cles`
  # ne verrait pas.
  verifier "$env_name : configuration au format strict CLE=valeur" '' \
    "$(grep -nvE '^[[:space:]]*(#.*)?$|^[A-Z][A-Z0-9_]*=' "${conf[@]}" || true)"
  verifier "$env_name : aucune valeur à l'allure de secret dans la configuration" '' \
    "$(grep -nE '^[^#]*(://[^/?#[:space:]]*@|-----BEGIN|sk_(live|test)_|rk_live_|whsec_)' "${conf[@]}" || true)"
  verifier "$env_name : aucune clé déclarée deux fois dans un même fichier" '' \
    "$(for f in "${conf[@]}"; do sed -n 's/^[[:space:]]*#\{0,1\}[[:space:]]*\([A-Z_][A-Z0-9_]*\)=.*/\1/p' "$f" | sort | uniq -d; done | tr '\n' ' ')"
  verifier "$env_name : aucune clé à la fois dans commun.conf et $env_name.conf" '' \
    "$(comm -12 <(cles "$CONFIG/commun.conf") <(cles "$CONFIG/$env_name.conf") | tr '\n' ' ')"
  verifier "$env_name : aucun secret du gabarit dans la configuration" '' \
    "$(comm -12 <(cles "${conf[@]}") <(cles "$EXEMPLES/$env_name.env.example") | tr '\n' ' ')"
  # … ni rien qui en porte le nom, même oublié du gabarit.
  verifier "$env_name : aucune clé au nom de secret dans la configuration" '' \
    "$(cles "${conf[@]}" | grep -E '(_SECRET|_PASSWORD|_PASS|_TOKEN|_API_KEY|_KEY_ID|_ACCESS_KEY|_PRIVATE_KEY|_JSON|_DSN|_AUTH|_CREDENTIALS|_WEBHOOK)$' | tr '\n' ' ')"
  verifier "$env_name : aucune valeur factice dans la configuration" '' \
    "$(grep -lE '^[^#]*CHANGE_MOI_' "${conf[@]}" || true)"
  verifier "$env_name : aucune variable de l'API déclarée vide dans la configuration" '' \
    "$(comm -12 <(sed -n 's/^\([A-Z_][A-Z0-9_]*\)=[[:space:]]*$/\1/p' "${conf[@]}" | sort -u) <(printf '%s\n' "$api") | tr '\n' ' ')"
  verifier "$env_name : chaque variable du schéma de l'API est portée par le dépôt" '' \
    "$(comm -23 <(printf '%s\n' "$api") <(cles "${conf[@]}" "$EXEMPLES/$env_name.env.example") | tr '\n' ' ')"
  verifier "$env_name : la pile se lit sans aucun avertissement de Compose" '' \
    "$(cat "$TMP/$env_name.err")"
done
# L'état ne se versionne pas : il vit dans etat.env.
verifier "ni CARLYS_TAG ni CARLYS_API_REPLICAS dans le dépôt" '' \
  "$(actives "$CONFIG"/*.conf "$EXEMPLES"/staging.env.example "$EXEMPLES"/production.env.example | grep -xE 'CARLYS_TAG|CARLYS_API_REPLICAS' | tr '\n' ' ')"

banc_bilan
