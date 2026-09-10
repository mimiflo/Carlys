# shellcheck shell=bash
# L'écart entre ce que le code EXIGE et ce que le .env porte vraiment.
#
# POURQUOI CE FICHIER EXISTE. `doctor` portait une ligne écrite à la main :
#
#     if [ "$(env_value CARLYS_API_HOST_PORT_LAST "$file" '')" = '' ]; then ...
#
# Elle était juste le jour où elle a été écrite. Elle ne l'est plus dès qu'une
# variable obligatoire s'ajoute à compose.yml — et rien ne le signale. C'est la
# règle du dépôt appliquée à l'orchestrateur lui-même : les écarts se comptent,
# ils ne se recopient pas.
#
# LE PRINCIPE. On ne réimplémente pas la vérification de Docker Compose : on la
# LUI DEMANDE. `docker compose config -q` est l'oracle exact — il connaît les
# variables obligatoires (`${VAR:?message}`), tolère celles que `dc` fournit
# autrement (COMPOSE_PROJECT_NAME arrive par --project-name, mesuré), et rend le
# message d'erreur qui nommera la variable au moment du déploiement.
#
# Il a en plus la propriété qui compte pour un diagnostic : il fonctionne DÉMON
# DOCKER ARRÊTÉ (mesuré : code de retour 0, `docker info` injoignable). Le
# moment où l'on a le plus besoin de `doctor` est justement celui où Docker ne
# répond plus.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# Les clés ACTIVES d'un fichier .env, une par ligne, sans les valeurs.
# Les lignes commentées et les lignes vides sortent d'elles-mêmes : le motif
# exige une clé en majuscules collée à un `=` en début de ligne.
envcheck_cles() {
  [ -f "$1" ] || return 0
  sed -n 's/^[[:space:]]*\(export[[:space:]][[:space:]]*\)\{0,1\}\([A-Z_][A-Z_0-9]*\)=.*/\2/p' "$1"
}

# Les clés déclarées PLUSIEURS fois dans un même .env.
#
# Pourquoi c'est un défaut et pas une curiosité : `env_value` prend la
# DERNIÈRE (`grep ... | tail -n 1`), et le lecteur de .env de Compose fait de
# même. Un fichier où `CARLYS_AUTO_UPDATE=oui` est suivi trente lignes plus bas
# d'un `CARLYS_AUTO_UPDATE=non` recopié par mégarde se comporte comme si la
# première ligne n'existait pas — sans le moindre message. C'est exactement ce
# que produit un `cat exemple >> .env`.
envcheck_doublons() {
  envcheck_cles "$1" | sort | uniq -d
}

# Le fichier d'exemple d'un environnement, s'il existe.
envcheck_exemple() {
  printf '%s/%s.env.example' "$CARLYS_ENV_EXAMPLES_DIR" "$1"
}

# Les clés actives de l'exemple absentes du .env réel.
#
# INFORMATIF, pas bloquant : un réglage introduit après la création du .env a
# toujours un défaut côté script (`env_value CLE "$f" <défaut>`), sans quoi
# `compose config` l'aurait déjà refusé. La liste sert à voir ce qui est
# DISPONIBLE, pas ce qui manque.
envcheck_nouveautes() {
  local env_name="$1" file="$2" exemple
  exemple="$(envcheck_exemple "$env_name")"
  [ -f "$exemple" ] || return 0
  comm -13 <(envcheck_cles "$file" | sort -u) <(envcheck_cles "$exemple" | sort -u)
}

# `envcheck_env <env> <.env>` — les trois contrôles. Rend 1 si quelque chose
# empêcherait la pile de démarrer ou trahirait silencieusement une intention.
envcheck_env() {
  local env_name="$1" file="$2" defaut=0 sortie cle valeur exemple

  # 1. L'oracle. Ce que Compose accepte ou refuse, dit par Compose.
  if sortie="$(dc "$env_name" "$file" config -q 2>&1)"; then
    ok "  Compose accepte ce .env"
  else
    warn "  Compose REFUSE ce .env — la pile ne peut pas démarrer :"
    printf '%s\n' "$sortie" | sed 's/^/        /' >&2
    defaut=1
  fi

  # 2. Le piège silencieux.
  while read -r cle; do
    [ -n "$cle" ] || continue
    warn "  $cle est déclarée PLUSIEURS FOIS — seule la DERNIÈRE compte"
    warn "        les voir : grep -n '^$cle=' $file"
    defaut=1
  done < <(envcheck_doublons "$file")

  # 3. Ce que l'exemple propose et que ce fichier n'a pas.
  exemple="$(envcheck_exemple "$env_name")"
  while read -r cle; do
    [ -n "$cle" ] || continue
    valeur="$(env_value "$cle" "$exemple" '')"
    info "  $cle absente — l'exemple propose : $cle=${valeur}"
  done < <(envcheck_nouveautes "$env_name" "$file")

  return "$defaut"
}
