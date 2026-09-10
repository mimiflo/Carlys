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
# CE QUE L'ORACLE NE COUVRE PAS, et qu'il faut donc regarder à côté. Compose
# n'interpole que ce que compose.yml nomme ; tout ce qui traverse `env_file`
# lui est opaque. Les quatre contrôles supplémentaires ci-dessous viennent
# chacun d'une panne mesurée, pas d'une précaution de principe :
#
#   - une clé DÉCLARÉE DEUX FOIS : c'est la dernière qui gagne, en silence ;
#   - une clé DE L'API active mais VIDE (`CLE=`) : Zod refuse la chaîne vide
#     même là où il a un `.default()`, et l'API ne démarre pas. De l'API
#     SEULEMENT : `COMPOSE_PROFILES=` est vide exprès en production ;
#   - un `CHANGE_MOI_` resté en place : les exemples documentent ce contrôle
#     depuis toujours, personne ne l'exécutait ;
#   - une clé active de l'exemple ABSENTE du fichier réel.
#
# CE QUE LE LECTEUR DE .env D'ICI NE COUVRE PAS, dit franchement plutôt
# qu'oublié : Compose accepte des valeurs multi-lignes entre guillemets
# (mesuré, v5.1.1), pas le motif de `envcheck_cles`. Une ligne de continuation
# qui ressemble à `CLE=` compterait donc pour une clé. Le seul champ du dépôt
# concerné est FIREBASE_SERVICE_ACCOUNT_JSON, que les exemples imposent déjà
# sur UNE seule ligne. La limite est connue et bornée ; la lever demanderait un
# second lecteur complet, ce qui coûterait plus cher que le cas qu'il couvre.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# Les clés ACTIVES d'un fichier .env, une par ligne, sans les valeurs.
#
# LE MOTIF TOLÈRE CE QUE COMPOSE TOLÈRE, et c'est tout l'enjeu : Compose rogne
# les espaces autour de la clé, donc `LOG_LEVEL =trace` est retenu par lui et
# écrase le `LOG_LEVEL=debug` d'au-dessus. Un motif qui exige le `=` collé ne
# verrait qu'une occurrence et laisserait passer le doublon — sous sa forme la
# plus invisible, une espace parasite. Les minuscules sont admises pour la
# même raison.
envcheck_cles() {
  [ -r "$1" ] || return 1
  sed -n 's/^[[:space:]]*\(export[[:space:]][[:space:]]*\)\{0,1\}\([A-Za-z_][A-Za-z_0-9]*\)[[:space:]]*=.*/\2/p' "$1"
}

# Le motif qui retrouve UNE clé, aligné sur envcheck_cles. Sert aux messages
# d'aide : une commande de remédiation qui ne montre pas ce qu'on vient de
# signaler coûte plus cher qu'un message absent — l'exploitant tape la ligne
# fournie, ne voit rien, et conclut que le diagnostic se trompe.
envcheck_motif() {
  printf '^[[:space:]]*(export[[:space:]]+)?%s[[:space:]]*=' "$1"
}

# Les clés déclarées PLUSIEURS fois dans un même .env.
#
# Pourquoi c'est un défaut et pas une curiosité : `env_value` prend la
# DERNIÈRE, et le lecteur de .env de Compose fait de même. Un fichier où
# `CARLYS_AUTO_UPDATE=oui` est suivi trente lignes plus bas d'un
# `CARLYS_AUTO_UPDATE=non` recopié par mégarde se comporte comme si la première
# ligne n'existait pas — sans le moindre message. C'est exactement ce que
# produit un `cat exemple >> .env`.
envcheck_doublons() {
  envcheck_cles "$1" | sort | uniq -d
}

# Les clés dont la valeur est VIDE alors que la ligne est active.
#
# Les deux exemples consacrent une de leurs « quatre règles qui coûtent cher »
# à ce cas : une variable facultative se laisse COMMENTÉE, jamais vide. `CLE=`
# arrive dans le conteneur comme chaîne vide, et Zod n'applique un `.default()`
# que sur une valeur ABSENTE — jamais sur une chaîne vide. `S3_REGION=` fait
# donc refuser le démarrage aussi sûrement qu'un secret trop court.
envcheck_vides() {
  [ -r "$1" ] || return 1
  sed -n 's/^[[:space:]]*\(export[[:space:]][[:space:]]*\)\{0,1\}\([A-Za-z_][A-Za-z_0-9]*\)[[:space:]]*=[[:space:]]*$/\2/p' "$1"
}

# Le fichier de schéma de l'API, qui décide de ce que « vide » veut dire.
envcheck_schema_api() {
  printf '%s/apps/api/src/config/env.schema.ts' "$CARLYS_REPO_DIR"
}

# Les variables que l'API VALIDE, tirées du schéma Zod lui-même.
#
# POURQUOI CETTE LISTE EXISTE, alors qu'aucune autre n'existe ici. Le contrôle
# des valeurs vides repose sur un fait qui n'est vrai QUE côté API : Zod refuse
# la chaîne vide, même là où il a un `.default()`. Appliqué à une variable que
# l'API ne lit pas, il n'affirme plus rien — et il s'est trompé, sur un vrai
# serveur, à la première exécution : `COMPOSE_PROFILES=` est VIDE EXPRÈS en
# production (« AUCUN profil : Mailpit ne démarre pas ici », production.env
# .example:68), et l'annoncer comme « l'API refusera de démarrer » était
# exactement le mensonge de diagnostic que ce fichier existe pour supprimer.
#
# La liste n'est donc pas tenue ici : elle est LUE dans le schéma, qui fait foi.
# Mesuré : 50 clés extraites, dont les 8 absentes des exemples sont précisément
# les 8 qui y sont commentées parce que facultatives. Aucun faux positif.
envcheck_cles_api() {
  local schema
  schema="$(envcheck_schema_api)"
  [ -r "$schema" ] || return 1
  grep -oE '^[[:space:]]+[A-Z][A-Z_0-9]*:' "$schema" | tr -d ' :' | sort -u
}

# Les clés actives dont la valeur porte encore un CHANGE_MOI_.
#
# Les exemples documentent ce contrôle depuis leur première ligne
# (« vérifier qu'il n'en reste aucun »). Personne ne l'exécutait. Un
# CHANGE_MOI_ actif n'est pas une valeur oubliée sans conséquence : les
# placeholders sont assez longs pour passer la validation Zod — 49 caractères
# pour le JWT, minimum exigé 32 — donc l'API DÉMARRE, et signe ses jetons avec
# une chaîne publiée dans un dépôt Git.
envcheck_change_moi() {
  [ -r "$1" ] || return 1
  sed -n 's/^[[:space:]]*\(export[[:space:]][[:space:]]*\)\{0,1\}\([A-Za-z_][A-Za-z_0-9]*\)[[:space:]]*=.*CHANGE_MOI_.*/\2/p' "$1"
}

# Le fichier d'exemple d'un environnement, s'il existe.
envcheck_exemple() {
  printf '%s/%s.env.example' "$CARLYS_ENV_EXAMPLES_DIR" "$1"
}

# Les clés actives de l'exemple absentes du .env réel.
#
# ACTIVES seulement, et c'est mesuré : les huit clés commentées des exemples
# sont toutes `.optional()` ou `.default()` côté Zod, et chaque réglage compose
# commenté (CARLYS_SCALE_*, CARLYS_HEAL_*, …) est lu avec un défaut explicite.
# Ignorer les lignes commentées ne cache donc rien. Inversement, une clé ACTIVE
# dans l'exemple est une clé que l'exemple affirme nécessaire : son absence est
# un défaut, pas une information.
envcheck_nouveautes() {
  local env_name="$1" file="$2" exemple
  exemple="$(envcheck_exemple "$env_name")"
  [ -f "$exemple" ] || return 0
  comm -13 <(envcheck_cles "$file" | sort -u) <(envcheck_cles "$exemple" | sort -u)
}

# `envcheck_env <env> <.env>` — les cinq contrôles. Rend 1 si quelque chose
# empêcherait la pile de démarrer ou trahirait silencieusement une intention.
envcheck_env() {
  local env_name="$1" file="$2" defaut=0 sortie cle api

  # AVANT TOUT LE RESTE. Sans cette garde, un .env en 600 root lu sans sudo
  # fait échouer chaque `sed` ; le code de retour est perdu par les
  # substitutions de processus, et `comm` compare une liste VIDE à l'exemple :
  # doctor déroule soixante lignes « CLÉ absente » qui décrivent un fichier
  # complet. Le diagnostic mentirait sur la cause.
  if [ ! -r "$file" ]; then
    warn "  $file ILLISIBLE par $(id -un) — diagnostic impossible"
    warn "        relancer avec sudo"
    return 1
  fi

  # 1. L'oracle. Ce que Compose accepte ou refuse, dit par Compose.
  #
  # ET CE QU'IL MURMURE. `config -q` rend 0 EN PRÉVENANT dans le cas que
  # l'en-tête des exemples désigne comme « celui qui fait perdre une soirée » :
  # un `$` dans une valeur ouvre une substitution. `MDP=mot$de$passe` devient
  # `mot`, Compose écrit ses avertissements sur la sortie d'erreur, et rend 0.
  # Capturer cette sortie puis la jeter parce que le code vaut 0, ce serait
  # l'échec silencieux que le dépôt s'interdit — sur le seul contrôle qui
  # prétend ne rien réimplémenter pour ne rien manquer.
  if sortie="$(dc "$env_name" "$file" config -q 2>&1)"; then
    if [ -n "$sortie" ]; then
      warn "  Compose accepte ce .env mais PRÉVIENT — valeur tronquée ?"
      warn "        un « \$ » dans une valeur ouvre une substitution : le DOUBLER en « \$\$ »"
      printf '%s\n' "$sortie" | sed 's/^/        /' >&2
      defaut=1
    else
      ok "  Compose accepte ce .env"
    fi
  else
    warn "  Compose REFUSE ce .env — la pile ne peut pas démarrer :"
    printf '%s\n' "$sortie" | sed 's/^/        /' >&2
    defaut=1
  fi

  # 2. Le piège silencieux.
  while read -r cle; do
    [ -n "$cle" ] || continue
    warn "  $cle est déclarée PLUSIEURS FOIS — seule la DERNIÈRE compte"
    warn "        les voir : grep -nE '$(envcheck_motif "$cle")' $file"
    defaut=1
  done < <(envcheck_doublons "$file")

  # 3. Active mais vide — POUR LES SEULES VARIABLES DE L'API.
  #
  # Restreint au schéma Zod, et pas par prudence : c'est le seul périmètre où
  # « vide » veut dire quelque chose. Une variable de compose vide est jugée
  # par le contrôle 1, qui refuse les `${VAR:?}` et laisse passer le reste —
  # y compris les vides voulues, `COMPOSE_PROFILES=` en production en tête.
  if api="$(envcheck_cles_api)"; then
    api=" $(printf '%s' "$api" | tr '\n' ' ') "
    while read -r cle; do
      [ -n "$cle" ] || continue
      case "$api" in *" $cle "*) ;; *) continue ;; esac
      warn "  $cle est déclarée VIDE — l'API refusera de démarrer"
      warn "        une variable facultative se COMMENTE, elle ne se vide pas"
      warn "        (Zod refuse la chaîne vide même là où il a un défaut)"
      defaut=1
    done < <(envcheck_vides "$file")
  else
    info "  schéma de l'API illisible ($(envcheck_schema_api)) —"
    info "    contrôle des valeurs vides NON EXÉCUTÉ"
  fi

  # 4. Les valeurs factices restées en place.
  while read -r cle; do
    [ -n "$cle" ] || continue
    warn "  $cle porte encore un CHANGE_MOI_ — valeur FACTICE, publiée dans le dépôt"
    warn "        $(envsync_conseil "$cle" "$env_name")"
    defaut=1
  done < <(envcheck_change_moi "$file")

  # 5. Ce que l'exemple porte en clair et que ce fichier n'a pas.
  while read -r cle; do
    [ -n "$cle" ] || continue
    warn "  $cle absente — $(envsync_conseil "$cle" "$env_name")"
    defaut=1
  done < <(envcheck_nouveautes "$env_name" "$file")

  return "$defaut"
}
