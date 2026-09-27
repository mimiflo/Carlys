# shellcheck shell=bash
# La purge des comptes supprimés, une fois par jour.
#
# POURQUOI ELLE TOURNE TOUTE SEULE. Supprimer son compte désactive tout de
# suite et libère l'identité ; l'historique (séances, repas, mesures,
# conversations du coach, encouragements…) restait ensuite rattaché à un
# identifiant, indéfiniment, alors que la politique de confidentialité et
# l'écran de suppression promettent un effacement après un délai.
# `dist/cli/deleted-accounts-purge` efface pour de bon les comptes supprimés
# depuis plus de CARLYS_ACCOUNT_PURGE_DAYS jours (30 par défaut, la valeur
# du CLI), photos privées comprises. Tant qu'il fallait qu'un exploitant y
# pense, la promesse n'était pas tenue : la supervision la lance elle-même,
# une fois par jour, et alerte quand elle échoue.
#
# Même rythme, même réessai, même alerte que le balayage des photos : la
# mécanique est partagée (_quotidien.sh). Chargé par _common.sh. Aucun effet
# de bord au chargement.

# `purge_comptes_lancer <env> <fichier .env> [options du CLI]` — rend le code
# du CLI (1 si un compte n'a pas pu être effacé, 2 sur un refus). Le délai
# vient de CARLYS_ACCOUNT_PURGE_DAYS s'il est posé dans le .env ; sinon le
# CLI applique le sien. PAS `--no-deps` : la commande lit PostgreSQL et le
# bucket privé de MinIO, qui doivent être debout.
purge_comptes_lancer() {
  local env_name="$1" file="$2" jours; shift 2
  jours="$(env_value CARLYS_ACCOUNT_PURGE_DAYS "$file" "")"
  if [ -n "$jours" ]; then
    set -- --delai-jours "$jours" "$@"
  fi
  dc "$env_name" "$file" run --rm -T api node dist/cli/deleted-accounts-purge "$@"
}

# `purge_comptes_si_due <env> <fichier .env>` — la purge quotidienne de la
# passe de supervision (rythme, réessai et alerte : _quotidien.sh).
purge_comptes_si_due() {
  quotidien_si_du "$1" "$2" purge_comptes deleted-accounts-purge purge_comptes_lancer \
    "Comptes supprimés à effacer" "Comptes supprimes non effaces" \
    "La purge quotidienne (dist/cli/deleted-accounts-purge) a échoué." \
    "Des comptes supprimés depuis plus que le délai gardent leurs données." \
    "" \
    "La relancer à la main, et lire ce qu'elle dit :" \
    "  $CARLYS_LIB_DIR/carlysctl deleted-accounts-purge $1 --a-blanc" \
    "  $CARLYS_LIB_DIR/carlysctl deleted-accounts-purge $1"
}
