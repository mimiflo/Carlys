# shellcheck shell=bash
# Mémoire de l'orchestrateur, entre deux passages.
#
# POURQUOI IL EN FAUT UNE. Un superviseur qui ne se souvient de rien ne peut
# décider que sur l'instant : il ajouterait un exemplaire sur un pic de trois
# secondes et le retirerait sur le creux suivant. Les décisions qui comptent —
# calculer un DÉBIT (deux mesures et le temps qui les sépare), attendre avant de
# réduire, refuser de réparer en boucle — ont toutes besoin de savoir ce qui
# s'est passé au tour d'avant.
#
# Un fichier clé=valeur par environnement, dans le répertoire de
# l'environnement. Pas de base, pas de format binaire : ce fichier doit pouvoir
# se lire et se corriger avec un éditeur à trois heures du matin.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

state_file() { printf '%s/%s/orchestrateur.etat' "$CARLYS_ROOT" "$1"; }

# `state_get <env> <clé> [défaut]`
state_get() {
  local env_name="$1" cle="$2" defaut="${3-}" fichier valeur
  fichier="$(state_file "$env_name")"
  [ -f "$fichier" ] || { printf '%s' "$defaut"; return 0; }
  # Dernière occurrence : si le fichier a été édité à la main et porte deux
  # fois la clé, c'est la plus récente qui gagne.
  valeur="$(awk -F= -v k="$cle" '$1 == k { sub(/^[^=]*=/, ""); v = $0 } END { print v }' "$fichier")"
  [ -n "$valeur" ] && printf '%s' "$valeur" || printf '%s' "$defaut"
}

# `state_set <env> <clé> <valeur>`
#
# Réécriture ATOMIQUE : le fichier est reconstruit à côté puis déplacé. Sans
# cela, une coupure au milieu de l'écriture laisserait un état tronqué, qui se
# relirait sans erreur et ferait décider de travers.
state_set() {
  local env_name="$1" cle="$2" valeur="$3" fichier temporaire
  fichier="$(state_file "$env_name")"
  mkdir -p "$(dirname "$fichier")"
  temporaire="$(mktemp "${fichier}.XXXXXX")"
  if [ -f "$fichier" ]; then
    grep -v "^${cle}=" "$fichier" > "$temporaire" || true
  fi
  printf '%s=%s\n' "$cle" "$valeur" >> "$temporaire"
  chmod 600 "$temporaire"
  mv "$temporaire" "$fichier"
}

# `state_set_many <env> <clé> <valeur> [<clé> <valeur>…]`
#
# Une seule réécriture pour plusieurs clés : enchaîner des `state_set` sur un
# échantillon de métriques ferait autant de réécritures que de valeurs, et
# laisserait le fichier dans un état MIXTE si l'une échoue — la moitié des
# compteurs du tour d'avant, l'autre moitié de celui-ci, donc un débit calculé
# sur deux instants différents.
state_set_many() {
  local env_name="$1"; shift
  local fichier temporaire cle valeur
  fichier="$(state_file "$env_name")"
  mkdir -p "$(dirname "$fichier")"
  temporaire="$(mktemp "${fichier}.XXXXXX")"
  [ -f "$fichier" ] && cp "$fichier" "$temporaire"
  while [ "$#" -ge 2 ]; do
    cle="$1"; valeur="$2"; shift 2
    grep -v "^${cle}=" "$temporaire" > "${temporaire}.n" 2>/dev/null || true
    mv "${temporaire}.n" "$temporaire"
    printf '%s=%s\n' "$cle" "$valeur" >> "$temporaire"
  done
  chmod 600 "$temporaire"
  mv "$temporaire" "$fichier"
}

# Horodatage en secondes depuis l'époque — la seule forme comparable sans
# analyse de date.
maintenant() { date -u +%s; }
