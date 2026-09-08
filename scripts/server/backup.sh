#!/usr/bin/env bash
# Sauvegarde des bases PostgreSQL du serveur dédié.
#
#     scripts/server/backup.sh              # les deux environnements
#     scripts/server/backup.sh staging      # un seul
#
# POURQUOI PASSER PAR LE CONTENEUR. Les bases ne publient AUCUN port sur
# l'hôte (contrat de conception) : elles ne sont joignables que sur le réseau
# Compose de leur environnement. Le `pg_dump` s'exécute donc DANS le conteneur
# postgres, ce qui règle en prime le piège de version : un pg_dump 16 installé
# sur l'hôte refuse de sauvegarder un serveur 17 (« server version mismatch »),
# alors que celui de l'image a par construction la version du serveur.
#
# FORMAT custom (-Fc) et non SQL brut : il se restaure sélectivement
# (pg_restore -t), se compresse tout seul, et porte un en-tête vérifiable —
# ce script s'en sert pour refuser un dump tronqué plutôt que de garder un
# fichier qui ne se restaurera pas le jour où on en aura besoin.
#
# ÉCRITURE ATOMIQUE : le dump part dans un fichier .part, renommé seulement
# après vérification. Une sauvegarde interrompue (disque plein, conteneur tué)
# ne laisse donc jamais un fichier d'apparence normale mais inutilisable.
#
# RESTAURER (la sauvegarde qu'on n'a jamais restaurée n'en est pas une) :
#   docker compose -p carlys_staging --env-file /srv/carlys/staging/.env \
#     -f infrastructure/server/compose.yml exec -T postgres \
#     pg_restore -U <user> -d <base> --clean --if-exists < <fichier>.dump
set -euo pipefail

# shellcheck source=scripts/server/_common.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/_common.sh"

RETENTION_DAYS="${CARLYS_BACKUP_RETENTION_DAYS:-14}"

usage() {
  cat >&2 <<'FIN'
Usage : backup.sh [staging|production]

  Sans argument : sauvegarde les deux environnements présents.
  Les dumps vont dans $CARLYS_ROOT/backups (défaut /srv/carlys/backups),
  nommés <environnement>-<horodatage UTC>.dump, rétention 14 jours.

Variables :
  CARLYS_ROOT                     racine des données (défaut /srv/carlys)
  CARLYS_BACKUP_RETENTION_DAYS    rétention en jours (défaut 14)
FIN
  exit 2
}

case "${1-}" in
  '') TARGETS=(staging production) ;;
  staging | production) TARGETS=("$1") ;;
  *) usage ;;
esac

require_commands docker
require_compose_file

BACKUP_DIR="$(backups_dir)"
mkdir -p "$BACKUP_DIR"
# Un dump contient TOUTES les données personnelles de la base : il n'est
# lisible que par son propriétaire.
chmod 700 "$BACKUP_DIR" 2>/dev/null || true

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
failures=0
made=0

for env_name in "${TARGETS[@]}"; do
  step "Sauvegarde — $env_name"
  file="$(env_file "$env_name")"
  if [ ! -f "$file" ]; then
    info "environnement absent ($file) — ignoré"
    continue
  fi

  project="$(compose_project "$env_name" "$file")"
  db_user="$(env_value POSTGRES_USER "$file" carlys)"
  db_name="$(env_value POSTGRES_DB "$file" "carlys_${env_name}")"

  if ! dc "$env_name" "$file" ps --status running --services 2>/dev/null | grep -qx postgres; then
    warn "postgres ne tourne pas pour $env_name (projet $project) — RIEN n'a été sauvegardé"
    failures=$((failures + 1))
    continue
  fi

  target="$BACKUP_DIR/${env_name}-${STAMP}.dump"
  partial="${target}.part"

  # PGPASSWORD n'est pas nécessaire par la socket locale du conteneur (auth
  # « trust » pour les connexions locales dans l'image officielle), mais on le
  # transmet s'il est connu : une image durcie pourrait l'exiger.
  if ! dc "$env_name" "$file" exec -T \
      --env "PGPASSWORD=$(env_value POSTGRES_PASSWORD "$file")" \
      postgres pg_dump -U "$db_user" -d "$db_name" --format=custom --no-owner \
      > "$partial" 2>"${partial}.err"; then
    warn "pg_dump a échoué pour $env_name (base $db_name, rôle $db_user) :"
    sed 's/^/     /' < "${partial}.err" >&2 || true
    rm -f "$partial" "${partial}.err"
    failures=$((failures + 1))
    continue
  fi
  rm -f "${partial}.err"

  # Un dump au format custom commence par la signature « PGDMP ». Ce contrôle
  # attrape le cas le plus vicieux : un fichier de taille non nulle rempli d'un
  # message d'erreur, qui passerait un test « le fichier existe ».
  if [ "$(head -c 5 "$partial" 2>/dev/null)" != "PGDMP" ]; then
    warn "le dump de $env_name n'a pas la signature PGDMP attendue — rejeté"
    rm -f "$partial"
    failures=$((failures + 1))
    continue
  fi

  mv "$partial" "$target"
  chmod 600 "$target"
  ok "$(basename -- "$target") ($(du -h "$target" | cut -f1))"
  made=$((made + 1))
done

# ── Rétention ──────────────────────────────────────────────────────────────
# On ne purge QUE nos propres fichiers (motif <env>-*.dump) : un répertoire de
# sauvegardes finit toujours par contenir autre chose, et un `find -delete`
# large y ferait des dégâts silencieux.
step "Rétention ($RETENTION_DAYS jours)"
purged=0
while IFS= read -r old; do
  [ -n "$old" ] || continue
  rm -f -- "$old"
  info "purgé : $(basename -- "$old")"
  purged=$((purged + 1))
done < <(find "$BACKUP_DIR" -maxdepth 1 -type f \
  \( -name 'staging-*.dump' -o -name 'production-*.dump' \) \
  -mtime "+${RETENTION_DAYS}" -print 2>/dev/null | sort)
[ "$purged" -gt 0 ] || info "aucun fichier à purger"

step "Bilan"
info "sauvegardes créées : $made"
info "fichiers purgés    : $purged"
info "répertoire         : $BACKUP_DIR"

if [ "$failures" -gt 0 ]; then
  # Sortie non nulle : sous cron, c'est ce qui déclenche l'alerte. Une
  # sauvegarde qui échoue en silence est une sauvegarde qu'on découvre absente
  # le jour de la restauration.
  printf '\n%s✗ %s environnement(s) NON sauvegardé(s)%s\n' "$_c_red" "$failures" "$_c_off" >&2
  exit 1
fi
