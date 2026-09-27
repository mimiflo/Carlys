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

# `photos_balayer <env> <fichier .env> [--a-blanc]` — rend le code du CLI
# (1 si un effacement a échoué). PAS `--no-deps` : la commande lit PostgreSQL
# et le bucket privé de MinIO, qui doivent être debout.
photos_balayer() {
  local env_name="$1" file="$2"; shift 2
  dc "$env_name" "$file" run --rm -T api node dist/cli/meal-photos-sweep "$@"
}

# `photos_balayer_si_du <env> <fichier .env>` — le balayage quotidien de la
# passe de supervision (rythme, réessai et alerte : _quotidien.sh).
photos_balayer_si_du() {
  quotidien_si_du "$1" "$2" balayage_photos meal-photos-sweep photos_balayer \
    "Photos de repas orphelines" "Photos de repas orphelines non effacees" \
    "Le balayage quotidien du bucket privé (dist/cli/meal-photos-sweep) a échoué." \
    "Des photos de repas que leur propriétaire a supprimées restent stockées." \
    "" \
    "Le relancer à la main, et lire ce qu'il dit :" \
    "  $CARLYS_LIB_DIR/carlysctl meal-photos-sweep $1 --a-blanc" \
    "  $CARLYS_LIB_DIR/carlysctl meal-photos-sweep $1"
}
