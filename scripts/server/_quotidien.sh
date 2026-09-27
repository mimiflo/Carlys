# shellcheck shell=bash
# Les tâches QUOTIDIENNES de la supervision : un CLI de l'image API, lancé
# une fois par jour et par environnement, relancé dans l'heure après un échec,
# et une alerte tant qu'il échoue.
#
# Deux s'en servent, qui ne diffèrent que par leur commande et leurs mots : le
# balayage des photos de repas orphelines (_photos.sh) et la purge des comptes
# supprimés (_purge_comptes.sh). La mécanique était recopiée de l'un à l'autre ;
# elle vit ici, une fois, et un correctif du rythme ou du réessai vaut pour
# les deux.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

QUOTIDIEN_INTERVALLE_S=$((24 * 3600))
# Après un échec, un nouvel essai dans l'heure plutôt que le lendemain, sans
# pour autant relancer un conteneur à chaque passe de deux minutes contre un
# stockage qui ne répond pas.
QUOTIDIEN_REESSAI_S=3600

# `quotidien_si_du <env> <.env> <clé> <cli> <lanceur> <étape> <sujet d'alerte> [lignes d'alerte…]`
#
#   <clé>      nomme l'état (<clé> : dernier passage, <clé>_echec) et l'alerte ;
#   <cli>      dist/cli/<cli>.js, que l'image déployée doit porter ;
#   <lanceur>  la fonction qui lance le CLI : `<lanceur> <env> <.env>`, rend
#              son code.
#
# Ne fait rien tant que le dernier passage est récent, ni sur un
# environnement jamais déployé, ni si l'image est antérieure au CLI.
quotidien_si_du() {
  local env_name="$1" file="$2" cle="$3" cli="$4" lanceur="$5" etape="$6" sujet="$7"
  shift 7
  local dernier maintenant_s attente_s="$QUOTIDIEN_INTERVALLE_S"
  [ -n "$(deployed_current "$env_name")" ] || return 0
  dernier="$(state_get "$env_name" "$cle" 0)"
  maintenant_s="$(maintenant)"
  [ "$(state_get "$env_name" "${cle}_echec" non)" = oui ] && attente_s="$QUOTIDIEN_REESSAI_S"
  [ $((maintenant_s - dernier)) -ge "$attente_s" ] || return 0

  # Le passage est noté AVANT de lancer : réussi ou non, le suivant attend son
  # délai, et une commande qui plante ne se relance pas toutes les deux
  # minutes.
  state_set "$env_name" "$cle" "$maintenant_s"
  api_cli_present "$env_name" "$file" "$cli" || return 0
  step "$etape sur « $env_name »"
  if "$lanceur" "$env_name" "$file"; then
    state_set "$env_name" "${cle}_echec" non
    alerte_resoudre "$env_name" "$cle" "$sujet"
    return 0
  fi
  state_set "$env_name" "${cle}_echec" oui
  warn "$etape : échec, nouvel essai dans l'heure"
  alerte_signaler "$env_name" "$cle" "$sujet" "$@"
  return 1
}
