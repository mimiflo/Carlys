# shellcheck shell=bash
# La base d'aliments CIQUAL, importée toute seule par la supervision.
#
# POURQUOI ICI ET PAS DANS L'IMAGE. La table de l'Anses n'est pas livrée avec
# le code : la mettre dans le dépôt coûterait 3,5 Mo à chaque clone, et la
# télécharger pendant la construction des images rendrait la CI dépendante
# d'un site tiers (la leçon de MinIO, api-ci). Le serveur, lui, a le temps :
# il télécharge la distribution OFFICIELLE une fois, en vérifie l'empreinte
# épinglée ci-dessous, la garde sur disque, et l'importe une fois par version.
# Un site injoignable ne bloque rien : la recherche reste vide, l'alerte le
# dit, et le passage suivant réessaie dans l'heure (_quotidien.sh).
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# La version servie : la distribution XML de l'Anses (Licence Ouverte
# Etalab 2.0), épinglée par son empreinte. Une nouvelle version CIQUAL, c'est
# ces deux lignes, rien d'autre — après l'avoir essayée à blanc
# (`ciqual-import --a-blanc`). Sur une base qui a DÉJÀ une version, l'import
# refuse de lui-même une version qui retirerait plus d'un quart des aliments
# (l'alerte le dira).
CARLYS_CIQUAL_URL="${CARLYS_CIQUAL_URL:-https://ciqual.anses.fr/cms/sites/default/files/inline-files/XML_2020_07_07.zip}"
CARLYS_CIQUAL_SHA256="${CARLYS_CIQUAL_SHA256:-cab13941ca693b7007c2f0fed2288fd5b94073fe6d598c9773297cf37aa59ca8}"
# Commun aux deux environnements : le même fichier sert la recette et la production.
CARLYS_CIQUAL_DIR="${CARLYS_CIQUAL_DIR:-$CARLYS_ROOT/ciqual}"

# Un téléchargement raté le dit ici, pour TOUTE la machine : la passe suivante
# d'un autre environnement ne réessaie pas dans la demi-heure. Sinon un site
# lent coûtait ses délais deux fois par passe, verrou tenu, jusqu'à dépasser
# le délai de la minuterie et priver la production de sa supervision.
CARLYS_CIQUAL_PAUSE_MIN=30

# `ciqual_archive` — le chemin de l'archive vérifiée, téléchargée si besoin.
# Rend 1 (et rien sur la sortie) si elle est introuvable ou n'est pas la bonne.
ciqual_archive() {
  local cible="$CARLYS_CIQUAL_DIR/$CARLYS_CIQUAL_SHA256.zip" injoignable="$CARLYS_CIQUAL_DIR/.injoignable" tmp
  # L'empreinte sert aussi de NOM de fichier et de chemin monté : rien d'autre
  # que 64 hexadécimaux n'y entre.
  [[ "$CARLYS_CIQUAL_SHA256" =~ ^[0-9a-f]{64}$ ]] || { warn "empreinte CIQUAL mal formée"; return 1; }
  if [ -f "$cible" ] && [ "$(sha256sum < "$cible" | cut -d' ' -f1)" = "$CARLYS_CIQUAL_SHA256" ]; then
    printf '%s' "$cible"
    return 0
  fi
  mkdir -p "$CARLYS_CIQUAL_DIR" || return 1
  if [ -n "$(find "$injoignable" -mmin "-$CARLYS_CIQUAL_PAUSE_MIN" 2>/dev/null)" ]; then
    warn "table CIQUAL injoignable il y a moins de $CARLYS_CIQUAL_PAUSE_MIN min : pas de nouvel essai"
    return 1
  fi
  # Un téléchargement coupé par l'arrêt de la passe (systemd) ne traîne pas.
  find "$CARLYS_CIQUAL_DIR" -maxdepth 1 -name '.telechargement.*' -mmin +30 -delete 2>/dev/null || true
  tmp="$(mktemp "$CARLYS_CIQUAL_DIR/.telechargement.XXXXXX")" || return 1
  # HTTPS seulement, redirections comprises, et 20 Mo au plus (l'archive en
  # fait 3,5) : un site détourné ne remplit pas le disque avant que
  # l'empreinte ne le démasque. Délais courts : 3,5 Mo se téléchargent en
  # secondes, un site qui ne répond pas ne retient pas la passe.
  if ! curl -fsSL --proto '=https' --proto-redir '=https' --max-filesize 20000000 \
      --connect-timeout 15 -m 120 --retry 1 -o "$tmp" "$CARLYS_CIQUAL_URL"; then
    rm -f "$tmp"
    touch "$injoignable"
    warn "table CIQUAL injoignable ($CARLYS_CIQUAL_URL)"
    return 1
  fi
  rm -f "$injoignable"
  # L'EMPREINTE, PAS LA TAILLE NI LE NOM : c'est elle qui garantit que la
  # table importée est celle qui a été vérifiée (énergies, rapprochement du
  # scan d'assiette), et pas une page d'erreur ou un fichier changé en route.
  if [ "$(sha256sum < "$tmp" | cut -d' ' -f1)" != "$CARLYS_CIQUAL_SHA256" ]; then
    rm -f "$tmp"
    warn "table CIQUAL téléchargée, mais son empreinte n'est pas celle attendue : refusée"
    return 1
  fi
  chmod 644 "$tmp" && mv "$tmp" "$cible" || return 1
  # Les versions précédentes ne servent plus : la base a la nouvelle.
  find "$CARLYS_CIQUAL_DIR" -maxdepth 1 -name '*.zip' ! -name "$CARLYS_CIQUAL_SHA256.zip" -delete 2>/dev/null || true
  printf '%s' "$cible"
}

# `ciqual_importer <env> <.env> [--force [options du CLI…]]` — importe la
# version épinglée si cet environnement ne l'a pas déjà. Rend le code de
# l'import. `--force` : même déjà importée, avec les options passées au CLI
# (`--a-blanc` n'écrit rien, et ne note donc rien).
#
# Décompressée DANS le conteneur, dans son /tmp : rien à installer sur l'hôte
# (l'image porte `unzip`), rien d'extrait qui traîne sur le disque. Seuls les
# fichiers lus sont extraits (pas les 41 Mo de `sources_*`). `--no-deps` :
# seule la base est lue et écrite.
#
# `--accepter-retraits`, d'office au PREMIER import seulement : le garde-fou
# du CLI refuse une version qui retire plus d'un quart des aliments, et les
# quelques aliments d'essai d'une base neuve bloquaient ce premier import
# (mesuré : 8 retraits sur 8). Ensuite, il joue : une nouvelle version
# épinglée qui retirerait beaucoup s'arrête sur une alerte, pour qu'un humain
# la regarde (`carlysctl ciqual-import <env> --a-blanc`, puis
# `--accepter-retraits`).
ciqual_importer() {
  local env_name="$1" file="$2" archive deja a_blanc=non
  local -a options=()
  deja="$(state_get "$env_name" ciqual_importee '')"
  if [ "${3-}" = --force ]; then
    options=("${@:4}")
  elif [ "$deja" = "$CARLYS_CIQUAL_SHA256" ]; then
    return 0
  fi
  [ -n "$deja" ] || options+=(--accepter-retraits)
  case " ${options[*]-} " in *" --a-blanc "*) a_blanc=oui ;; esac
  archive="$(ciqual_archive)" || return 1
  # shellcheck disable=SC2016 # "$@" est développé dans le conteneur, pas ici
  dc "$env_name" "$file" run --rm --no-deps -T -v "$archive:/ciqual.zip:ro" api \
    sh -c 'mkdir -p /tmp/ciqual && unzip -q -o /ciqual.zip "alim_*" "compo_*" "const_*" -d /tmp/ciqual && exec node dist/cli/ciqual-import /tmp/ciqual "$@"' \
    sh ${options[@]+"${options[@]}"} || return 1
  [ "$a_blanc" = oui ] || state_set "$env_name" ciqual_importee "$CARLYS_CIQUAL_SHA256"
}

# `ciqual_importer_si_du <env> <.env>` — la passe de supervision.
#
# Version déjà en base : rien, pas même un conteneur. Version épinglée NOUVELLE
# (déploiement, ou dépôt avancé par la supervision) : tout de suite, sans
# attendre le rythme quotidien. Ensuite, le rythme de _quotidien.sh : réessai
# dans l'heure après un échec, et une alerte tant qu'il dure.
ciqual_importer_si_du() {
  [ "$(state_get "$1" ciqual_importee '')" != "$CARLYS_CIQUAL_SHA256" ] || return 0
  if [ "$(state_get "$1" ciqual_visee '')" != "$CARLYS_CIQUAL_SHA256" ]; then
    state_set_many "$1" ciqual_visee "$CARLYS_CIQUAL_SHA256" import_ciqual 0 import_ciqual_echec non
  fi
  quotidien_si_du "$1" "$2" import_ciqual ciqual-import ciqual_importer \
    "Base d'aliments CIQUAL" "Base d aliments CIQUAL non importee" \
    "L'import automatique de la table CIQUAL (dist/cli/ciqual-import) a échoué." \
    "Tant qu'elle manque, la recherche d'aliments et le scan d'assiette ne trouvent rien." \
    "" \
    "Voir ce qui coince, puis le relancer :" \
    "  $CARLYS_LIB_DIR/carlysctl ciqual-import $1 --a-blanc" \
    "  $CARLYS_LIB_DIR/carlysctl ciqual-import $1   (--accepter-retraits si la simulation le demande)"
}
