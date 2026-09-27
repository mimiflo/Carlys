# shellcheck shell=bash
# Le dump d'UNE base PostgreSQL — et le filet d'avant-migration qui s'en sert.
#
# DEUX APPELANTS, UNE SEULE DESCRIPTION DU DUMP : la sauvegarde nocturne
# (backup.sh) et deploy.sh, qui sauvegarde la base de production juste avant
# d'y appliquer une migration. Recopier le `pg_dump` dans deploy.sh l'aurait
# fait diverger au premier correctif ; appeler backup.sh tel quel aurait
# aussi lancé le miroir MinIO et ses instantanés — lent, et hors sujet avant
# une migration.
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

# `sauvegarde_base <env> <.env> <fichier cible>` — rend 0 si le fichier cible
# existe, porte la signature d'un dump et n'est lisible que par root.
#
# POURQUOI PASSER PAR LE CONTENEUR. Les bases ne publient AUCUN port sur
# l'hôte (contrat de conception) : `pg_dump` s'exécute donc DANS le conteneur
# postgres, ce qui règle en prime le piège de version — un pg_dump 16 installé
# sur l'hôte refuse de sauvegarder un serveur 17 (« server version mismatch »),
# celui de l'image a par construction la version du serveur.
#
# FORMAT custom (-Fc) : restauration sélective (pg_restore -t), compression,
# et un en-tête vérifiable — un fichier de taille non nulle rempli d'un
# message d'erreur passerait un test « le fichier existe », pas celui-ci.
#
# ÉCRITURE ATOMIQUE : le dump part dans un .part, renommé seulement après
# vérification. Une interruption ne laisse jamais un fichier d'apparence
# normale mais inutilisable.
#
# PGPASSWORD est lu DANS LE CONTENEUR, depuis POSTGRES_PASSWORD que le compose
# y place déjà — jamais passé en argument de `docker compose exec` : un
# `--env PGPASSWORD=…` le mettrait dans /proc/<pid>/cmdline, lisible par tout
# utilisateur local pendant le dump. Les guillemets simples garantissent que
# l'hôte ne développe pas la variable.
sauvegarde_base() {
  local env_name="$1" file="$2" target="$3" partial db_user db_name
  partial="${target}.part"
  db_user="$(env_value POSTGRES_USER "$file" carlys)"
  db_name="$(env_value POSTGRES_DB "$file" "carlys_${env_name}")"
  # shellcheck disable=SC2016 # développé par le shell DU CONTENEUR, voir ci-dessus
  if ! dc "$env_name" "$file" exec -T postgres sh -c \
      'PGPASSWORD="${POSTGRES_PASSWORD-}" exec pg_dump -U "$1" -d "$2" --format=custom --no-owner' \
      pg_dump "$db_user" "$db_name" \
      > "$partial" 2>"${partial}.err"; then
    warn "pg_dump a échoué pour $env_name (base $db_name, rôle $db_user) :"
    sed 's/^/     /' < "${partial}.err" >&2 || true
    rm -f "$partial" "${partial}.err"
    return 1
  fi
  rm -f "${partial}.err"
  if [ "$(head -c 5 "$partial" 2>/dev/null)" != "PGDMP" ]; then
    warn "le dump de $env_name n'a pas la signature PGDMP attendue : rejeté"
    rm -f "$partial"
    return 1
  fi
  mv "$partial" "$target"
  chmod 600 "$target"
}

# ── Le filet d'AVANT-MIGRATION ──────────────────────────────────────────────
#
# LE TROU QUE CECI BOUCHE. deploy.sh applique `prisma migrate deploy` sans
# retour possible : Prisma n'a pas de migration descendante, et un retour
# arrière ne restaure que le CODE. La seule copie de la base était celle de la
# nuit (cron de 3 h) : une migration destructrice — un DROP COLUMN généré par
# Prisma, une migration renommée comme celle de 12c471e — passée en production
# à 16 h emportait jusqu'à une journée d'écritures des utilisateurs, sans
# recours. Désormais, la base est sauvegardée JUSTE AVANT la migration, et un
# échec de cette sauvegarde arrête le déploiement : rien n'a été basculé.
#
# ACTIF PAR DÉFAUT EN PRODUCTION, INACTIF EN RECETTE. La recette porte des
# données de test et se redéploie à chaque poussée ; y empiler un dump par
# commit remplirait le disque pour rien. La variable CARLYS_DEPLOY_BACKUP
# (environnement du processus, sinon .env) change ce défaut — lue en FAILLE
# FERMÉE dans les deux sens : seul un NON franc désarme la production, seul
# un OUI franc arme la recette (vaut_oui / vaut_non, _common.sh).
sauvegarde_avant_migration_active() {
  local env_name="$1" file="$2" valeur
  valeur="${CARLYS_DEPLOY_BACKUP:-$(env_value CARLYS_DEPLOY_BACKUP "$file" '')}"
  if [ "$env_name" = production ]; then
    ! vaut_non "$valeur"
  else
    vaut_oui "$valeur"
  fi
}

# LA RÉTENTION DES DUMPS D'AVANT-MIGRATION : les N derniers, jamais au-delà
# de J jours. DEUX bornes, et chacune a sa raison.
#
# PAS les 14 jours de la sauvegarde nocturne : une migration qui a corrompu
# des données en silence peut se découvrir trois semaines plus tard, et le
# dump d'avant est alors la seule base PROPRE. D'où J = 30 par défaut.
#
# MAIS UN ÂGE MAXIMAL QUAND MÊME. Borner le seul NOMBRE ne borne rien dans le
# temps : avec des déploiements manuels (CARLYS_AUTO_UPDATE=non, le défaut),
# un trimestre sans déploiement laissait sur le disque des dumps de sept ou
# huit mois — avec les comptes supprimés entre-temps, que la purge
# quotidienne (deleted-accounts-purge, 30 jours) avait effacés de la base
# depuis longtemps. Aucune durée de conservation des sauvegardes n'aurait pu
# être annoncée (docs/legal/privacy.md). La borne d'âge s'applique donc aussi
# CHAQUE NUIT (backup.sh), pas seulement au déploiement suivant.
#
# J est indépendant de CARLYS_ACCOUNT_PURGE_DAYS, à dessein : raccourcir la
# purge des comptes ne doit pas retirer en silence le filet des migrations.
# La durée annoncée des sauvegardes est donc « au plus J jours ».
sauvegarde_avant_migration_gardees() {
  local n="${CARLYS_BACKUP_PREMIGRATION_KEEP:-3}"
  case "$n" in '' | *[!0-9]*) n=3 ;; esac
  [ "$n" -ge 1 ] || n=1
  printf '%s' "$n"
}

# `sauvegarde_avant_migration_jours_max <.env>` — J. Lu comme
# CARLYS_DEPLOY_BACKUP : environnement du processus, sinon .env, sinon 30.
# Une valeur illisible retombe sur 30 : la borne ne disparaît jamais.
sauvegarde_avant_migration_jours_max() {
  local j="${CARLYS_BACKUP_PREMIGRATION_MAX_DAYS:-$(env_value CARLYS_BACKUP_PREMIGRATION_MAX_DAYS "$1" '')}"
  case "$j" in '' | *[!0-9]*) j=30 ;; esac
  printf '%s' "$j"
}

# Motif des fichiers : il ne commence PAS par `<env>-`, pour échapper à la
# rétention À 14 JOURS de backup.sh (motif `<env>-*.dump`) ; backup.sh leur
# applique la leur, ci-dessous. Le nom trié suit l'ordre chronologique :
# l'horodatage vient avant le sha.
sauvegarde_avant_migration_motif() { printf 'avant-migration-%s-*.dump' "$1"; }

# `sauvegarde_avant_migration_purger <env> <.env> [dump à garder]` — applique
# les deux bornes : au-delà des N plus récents, ou plus vieux que J jours
# (même mesure que backup.sh : `find -mtime +J`). Le dump à garder, celui
# qu'on vient d'écrire, n'est jamais purgé, quelles que soient les bornes.
# Écrit sur la sortie standard le nombre de fichiers purgés ; les messages
# vont sur la sortie d'erreur.
sauvegarde_avant_migration_purger() {
  local env_name="$1" file="$2" garder="${3-}" dir motif vieux n=0
  dir="$(backups_dir)"
  motif="$(sauvegarde_avant_migration_motif "$env_name")"
  [ -d "$dir" ] || { printf '0'; return 0; }
  while IFS= read -r vieux; do
    [ -n "$vieux" ] && [ "$vieux" != "$garder" ] && [ -f "$vieux" ] || continue
    rm -f -- "$vieux"
    info "dump d'avant-migration purgé : $(basename -- "$vieux")" >&2
    n=$((n + 1))
  done < <(
    find "$dir" -maxdepth 1 -type f -name "$motif" -print | sort \
      | head -n "-$(sauvegarde_avant_migration_gardees)"
    find "$dir" -maxdepth 1 -type f -name "$motif" \
      -mtime "+$(sauvegarde_avant_migration_jours_max "$file")" -print
  )
  printf '%s' "$n"
}

# `sauvegarde_avant_migration <env> <.env> <sha12>` — écrit le chemin du dump
# sur la sortie standard, puis applique la rétention (ci-dessus) à cet
# environnement. Rend 1, sans rien purger, si le dump échoue.
sauvegarde_avant_migration() {
  local env_name="$1" file="$2" sha="$3" dir target
  dir="$(backups_dir)"
  mkdir -p "$dir"
  chmod 700 "$dir" 2>/dev/null || true
  target="$dir/avant-migration-${env_name}-$(date -u +%Y%m%dT%H%M%SZ)-${sha}.dump"
  sauvegarde_base "$env_name" "$file" "$target" || return 1
  sauvegarde_avant_migration_purger "$env_name" "$file" "$target" > /dev/null
  printf '%s' "$target"
}
