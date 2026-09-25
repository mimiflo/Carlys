# shellcheck shell=bash
# Le balayage des photos de repas orphelines, une fois par jour.
#
# POURQUOI IL TOURNE TOUT SEUL. Les photos de repas sont des données
# personnelles, rangées dans le bucket PRIVÉ. Leurs suppressions (repas
# supprimé, photo retirée ou remplacée, compte supprimé) effacent l'objet
# APRÈS la base, et un stockage qui ne répond pas à cet instant laisse un
# objet que plus aucune ligne ne cite : l'API le journalise, sans faire échouer
# la suppression, qui a bien eu lieu. `dist/cli/meal-photos-sweep` reprend
# ces orphelins. Tant qu'il fallait qu'un exploitant lise les journaux pour le
# lancer, la politique de confidentialité promettait un « passage suivant du
# nettoyage » qui ne passait jamais : la supervision le lance désormais
# elle-même, une fois par jour, et alerte quand il échoue.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# Un balayage par jour. Après un échec, on retente dans l'heure plutôt que le
# lendemain, sans pour autant relancer un conteneur à chaque passe de deux
# minutes contre un stockage qui ne répond pas.
PHOTOS_BALAYAGE_INTERVALLE_S=$((24 * 3600))
PHOTOS_BALAYAGE_REESSAI_S=3600

# Vrai si l'image API déployée porte la commande. Une image antérieure aux
# photos de repas ne l'a pas, et n'a jamais pu en stocker une.
photos_commande_presente() {
  local env_name="$1" file="$2"
  dc "$env_name" "$file" run --rm --no-deps -T --entrypoint test api \
    -f dist/cli/meal-photos-sweep.js >/dev/null 2>&1
}

# `photos_balayer <env> <fichier .env> [--a-blanc]` — rend le code du CLI
# (1 si un effacement a échoué). PAS `--no-deps` : la commande lit PostgreSQL
# et le bucket privé de MinIO, qui doivent être debout.
photos_balayer() {
  local env_name="$1" file="$2"; shift 2
  dc "$env_name" "$file" run --rm -T api node dist/cli/meal-photos-sweep "$@"
}

# `photos_balayer_si_du <env> <fichier .env>` — le balayage quotidien de la
# passe de supervision. Ne fait rien tant que le dernier passage est récent,
# ni sur un environnement jamais déployé.
photos_balayer_si_du() {
  local env_name="$1" file="$2" dernier maintenant_s attente_s
  [ -n "$(deployed_current "$env_name")" ] || return 0
  dernier="$(state_get "$env_name" balayage_photos 0)"
  maintenant_s="$(maintenant)"
  attente_s="$PHOTOS_BALAYAGE_INTERVALLE_S"
  [ "$(state_get "$env_name" balayage_photos_echec non)" = oui ] \
    && attente_s="$PHOTOS_BALAYAGE_REESSAI_S"
  [ $((maintenant_s - dernier)) -ge "$attente_s" ] || return 0

  # Le passage est noté AVANT de lancer : réussi ou non, le suivant attend
  # son délai, et un balayage qui plante ne se relance pas toutes les deux
  # minutes.
  state_set "$env_name" balayage_photos "$maintenant_s"
  if ! photos_commande_presente "$env_name" "$file"; then
    return 0
  fi
  step "Photos de repas orphelines de « $env_name »"
  if photos_balayer "$env_name" "$file"; then
    state_set "$env_name" balayage_photos_echec non
    alerte_resoudre "$env_name" balayage_photos "Photos de repas orphelines non effacees"
    return 0
  fi
  state_set "$env_name" balayage_photos_echec oui
  warn "balayage des photos de repas en échec : nouvel essai dans l'heure"
  alerte_signaler "$env_name" balayage_photos "Photos de repas orphelines non effacees" \
    "Le balayage quotidien du bucket privé (dist/cli/meal-photos-sweep) a échoué." \
    "Des photos de repas que leur propriétaire a supprimées restent stockées." \
    "" \
    "Le relancer à la main, et lire ce qu'il dit :" \
    "  $CARLYS_LIB_DIR/carlysctl meal-photos-sweep $env_name --a-blanc" \
    "  $CARLYS_LIB_DIR/carlysctl meal-photos-sweep $env_name"
  return 1
}
