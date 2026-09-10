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
# ne laisse donc jamais un fichier d'apparence normale mais inutilisable. Les
# fragments qu'une interruption brutale laisse malgré tout sont purgés au
# passage suivant (voir la section « Rétention »).
#
# CE QUI VAUT ÉCHEC, ET CE QUI N'EN EST PAS UN. Le code de retour de ce script
# EST le mécanisme d'alerte : cron l'envoie à l'opérateur. Il ne vaut donc que
# s'il ne se déclenche pas pour rien. Un environnement dont le DEPLOYED est
# vide n'a JAMAIS rien hébergé — setup.sh crée pourtant son .env dès le
# premier jour : on le saute sans compter d'échec. Un environnement DÉPLOYÉ
# dont postgres ne tourne pas, en revanche, a des données qui ne sont pas
# sauvegardées : celui-là fait sortir en erreur.
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

  Sans argument : sauvegarde les deux environnements DÉPLOYÉS.
  Les dumps vont dans $CARLYS_ROOT/backups (défaut /srv/carlys/backups),
  nommés <environnement>-<horodatage UTC>.dump, rétention 14 jours.

Codes de retour :
  0   toutes les bases attendues sont sauvegardées (un environnement jamais
      déployé est sauté, ce n'est pas un échec)
  1   au moins un environnement déployé n'a PAS pu être sauvegardé
  2   mauvaise utilisation

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
skipped=0
# Environnements ayant produit un dump NEUF ET VALIDE pendant cette exécution.
# Eux seuls verront leur rétention appliquée — voir la section « Rétention ».
reussis=''

for env_name in "${TARGETS[@]}"; do
  step "Sauvegarde — $env_name"
  file="$(env_file "$env_name")"
  if [ ! -f "$file" ]; then
    info "environnement absent ($file) — ignoré"
    skipped=$((skipped + 1))
    continue
  fi

  # « JAMAIS DÉPLOYÉ » N'EST PAS UNE PANNE, et c'est la distinction qui fait
  # vivre l'alerte. setup.sh crée les DEUX .env dès la mise en place ; pendant
  # toute la phase où seul staging tourne, la production existe sur le disque
  # sans avoir jamais rien hébergé. Compter cela comme un échec, c'est envoyer
  # un courriel d'alerte toutes les nuits pour une situation normale — et une
  # alerte qui crie tous les jours ne se lit plus, y compris le soir où elle
  # signale une vraie perte de sauvegarde.
  #
  # Le signal juste est DEPLOYED, tenu par deploy.sh : vide = rien n'a jamais
  # été déployé ici, il n'y a AUCUNE donnée à perdre. Non vide = un sha sert
  # (ou a servi) le trafic, donc une base existe : postgres à terre devient
  # alors une anomalie qui doit réveiller quelqu'un.
  deployed="$(deployed_current "$env_name")"
  if [ -z "$deployed" ]; then
    info "jamais déployé ($(deployed_file "$env_name") est vide) — aucune base à sauvegarder"
    info "ce n'est pas un échec : rien n'a encore tourné dans cet environnement."
    skipped=$((skipped + 1))
    continue
  fi

  project="$(compose_project "$env_name" "$file")"
  db_user="$(env_value POSTGRES_USER "$file" carlys)"
  db_name="$(env_value POSTGRES_DB "$file" "carlys_${env_name}")"

  if ! dc "$env_name" "$file" ps --status running --services 2>/dev/null | grep -qx postgres; then
    warn "postgres ne tourne pas pour $env_name (projet $project, sha déployé $deployed) — RIEN n'a été sauvegardé"
    warn "  cet environnement A été déployé : une base existe et n'est pas sauvegardée."
    warn "  Diagnostic : docker compose -p $project --env-file $file ps"
    failures=$((failures + 1))
    continue
  fi

  target="$BACKUP_DIR/${env_name}-${STAMP}.dump"
  partial="${target}.part"

  # PGPASSWORD n'est pas nécessaire par la socket locale du conteneur (auth
  # « trust » pour les connexions locales dans l'image officielle), mais une
  # image durcie pourrait l'exiger. Il est donc lu DANS LE CONTENEUR, depuis
  # POSTGRES_PASSWORD que le compose y place déjà — jamais passé en argument
  # de `docker compose exec`. Un `--env PGPASSWORD=…` mettrait le mot de passe
  # de production dans /proc/<pid>/cmdline, lisible par n'importe quel
  # utilisateur local pendant toute la durée du dump ; les guillemets simples
  # ci-dessous garantissent que l'hôte ne développe pas la variable.
  if ! dc "$env_name" "$file" exec -T postgres sh -c \
      'PGPASSWORD="${POSTGRES_PASSWORD-}" exec pg_dump -U "$1" -d "$2" --format=custom --no-owner' \
      pg_dump "$db_user" "$db_name" \
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
  reussis="$reussis $env_name"
done

# ── Médias (MinIO) ─────────────────────────────────────────────────────────
# LES MÉDIAS N'AVAIENT AUCUNE COPIE. Ce script ne faisait que pg_dump : les
# photos d'exercices, avatars et fichiers déposés vivaient dans le seul volume
# minio-data. Une base restaurée sans ses médias sert des URL mortes.
#
# LA FORME : un miroir logique par `mc mirror`, PAS un tar du volume. MinIO
# range ses objets dans un format interne (xl.meta, métadonnées d'effacement) ;
# le miroir passe par l'API S3 et rend des FICHIERS ORDINAIRES, restaurables
# avec n'importe quoi — y compris à la main, un par un.
#
# L'HISTORIQUE PAR LIENS DURS. Un miroir seul ne protège pas d'une suppression :
# l'objet effacé disparaît du miroir à la nuit suivante. Chaque nuit réussie
# est donc figée par `cp -al` — des liens durs, pas des copies : quatorze
# nuits d'historique coûtent UNE taille de bucket plus les seuls fichiers qui
# ont changé. Un objet supprimé du miroir reste vivant dans les instantanés
# qui le pointent.
#
# LES IDENTIFIANTS NE TOUCHENT PAS L'HÔTE. Le miroir tourne dans l'image `mc`
# du service minio-init, dont l'environnement compose porte déjà
# MINIO_ROOT_USER/PASSWORD — même raisonnement que PGPASSWORD plus haut :
# rien dans /proc/<pid>/cmdline.
step "Médias (MinIO)"
reussis_minio=''
for env_name in "${TARGETS[@]}"; do
  file="$(env_file "$env_name")"
  if [ ! -f "$file" ]; then
    continue
  fi
  deployed="$(deployed_current "$env_name")"
  if [ -z "$deployed" ]; then
    info "$env_name : jamais déployé — aucun média à sauvegarder"
    continue
  fi
  bucket="$(env_value S3_BUCKET "$file" '')"
  if [ -z "$bucket" ]; then
    warn "$env_name : S3_BUCKET absent du .env — médias NON sauvegardés"
    failures=$((failures + 1))
    continue
  fi
  if ! dc "$env_name" "$file" ps --status running --services 2>/dev/null | grep -qx minio; then
    warn "minio ne tourne pas pour $env_name — médias NON sauvegardés"
    failures=$((failures + 1))
    continue
  fi

  miroir="$BACKUP_DIR/minio-${env_name}"
  mkdir -p "$miroir/courant"
  chmod 700 "$miroir"

  # `--remove` : le miroir reflète EXACTEMENT le bucket — les suppressions
  # légitimes s'y propagent, et ce sont les instantanés qui gardent l'histoire.
  # `--no-deps` : minio tourne déjà (vérifié ci-dessus) ; laisser compose
  # démarrer des dépendances pendant une sauvegarde serait une surprise.
  if ! dc "$env_name" "$file" run --rm -T --no-deps \
      -v "$miroir/courant:/sauvegarde" \
      --entrypoint /bin/sh minio-init -c \
      'mc alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && exec mc mirror --remove --quiet "local/$1" /sauvegarde' \
      miroir "$bucket" > /dev/null 2>"$miroir/.erreur"; then
    warn "mc mirror a échoué pour $env_name (bucket $bucket) :"
    sed 's/^/     /' < "$miroir/.erreur" >&2 || true
    rm -f "$miroir/.erreur"
    failures=$((failures + 1))
    continue
  fi
  rm -f "$miroir/.erreur"

  instantane="$miroir/instantane-${STAMP}"
  if ! cp -al "$miroir/courant" "$instantane"; then
    warn "$env_name : l'instantané par liens durs a échoué — le miroir, lui, est à jour"
    failures=$((failures + 1))
    continue
  fi
  # `cp -a` PRÉSERVE la date du répertoire source. Une nuit sans aucun
  # changement laisse à `courant` une vieille date — l'instantané tout neuf
  # l'hériterait, et la rétention par -mtime le purgerait le soir même.
  touch "$instantane"

  nb="$(find "$instantane" -type f 2>/dev/null | wc -l)"
  ok "minio-${env_name}/instantane-${STAMP} ($nb fichier(s), $(du -sh "$instantane" 2>/dev/null | cut -f1))"
  made=$((made + 1))
  reussis_minio="$reussis_minio $env_name"
done

# ── Rétention ──────────────────────────────────────────────────────────────
# On ne purge QUE nos propres fichiers (motif <env>-*) : un répertoire de
# sauvegardes finit toujours par contenir autre chose — un dump manuel pris
# avant une migration délicate, des notes d'exploitation — et un
# `find -delete` large y ferait des dégâts silencieux.
purged=0
purge_older_than() {
  local days="$1" pattern="$2" old
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    rm -f -- "$old"
    info "purgé : $(basename -- "$old")"
    purged=$((purged + 1))
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "$pattern" \
    -mtime "+${days}" -print 2>/dev/null | sort)
}

# LA PURGE EST CONDITIONNÉE À UNE SAUVEGARDE NEUVE, PAR ENVIRONNEMENT.
#
# Purger inconditionnellement transforme une panne discrète en perte de
# données. Le scénario ne demande rien d'exotique : POSTGRES_USER modifié dans
# le .env sans l'être dans la base, ou partition pleine. `pg_dump` échoue
# chaque nuit, le script sort bien en 1 — mais le courriel de cron finit dans
# un filtre, et personne ne regarde. Au quinzième jour, la dernière sauvegarde
# VALABLE franchit `-mtime +14` et cette purge l'efface. L'environnement est
# alors sans aucune sauvegarde restaurable, et rien ne l'a dit plus fort que
# les quatorze nuits précédentes.
#
# La règle tenue ici : on ne jette une vieille sauvegarde que si l'on vient
# d'en écrire une neuve et vérifiée à la place. Par environnement, parce que
# la recette peut échouer pendant que la production réussit — gérer les deux
# ensemble ferait payer à l'une la panne de l'autre.
step "Rétention ($RETENTION_DAYS jours)"
for env_name in "${TARGETS[@]}"; do
  case " $reussis " in
    *" $env_name "*)
      purge_older_than "$RETENTION_DAYS" "${env_name}-*.dump"
      ;;
    *)
      warn "$env_name : aucune sauvegarde neuve cette nuit — rétention NON appliquée"
      warn "  les sauvegardes existantes sont conservées, même au-delà de $RETENTION_DAYS jours."
      ;;
  esac
done

# LES INSTANTANÉS MINIO, même règle, même raison : on ne jette un vieil
# instantané que si l'on vient d'en figer un neuf. Des RÉPERTOIRES cette
# fois — `purge_older_than` ne voit que des fichiers, et c'est voulu :
# élargir son motif aux répertoires lui ferait un jour avaler autre chose.
for env_name in "${TARGETS[@]}"; do
  [ -d "$BACKUP_DIR/minio-${env_name}" ] || continue
  case " $reussis_minio " in
    *" $env_name "*)
      while IFS= read -r vieux; do
        [ -n "$vieux" ] || continue
        rm -rf -- "$vieux"
        info "purgé : minio-${env_name}/$(basename -- "$vieux")"
        purged=$((purged + 1))
      done < <(find "$BACKUP_DIR/minio-${env_name}" -maxdepth 1 -type d \
        -name 'instantane-*' -mtime "+${RETENTION_DAYS}" -print 2>/dev/null | sort)
      ;;
    *)
      warn "minio-${env_name} : aucun instantané neuf cette nuit — rétention NON appliquée"
      ;;
  esac
done

# LES FRAGMENTS AUSSI. Un `.dump.part` est ce que laisse une sauvegarde
# interrompue en plein vol : serveur redémarré, conteneur tué, disque plein.
# Les chemins d'échec de ce script effacent le leur, mais celui qu'une
# interruption BRUTALE laisse derrière n'a plus personne pour le nettoyer — et
# la rétention ci-dessus ne le voit pas, puisqu'elle filtre sur `*.dump` et
# qu'un `.dump.part` n'y répond pas. Sans cette seconde passe, un serveur qui
# tue régulièrement ses sauvegardes accumule indéfiniment des fragments de la
# taille d'une base, jusqu'à remplir la partition censée les accueillir.
#
# Un jour, et pas quatorze : un fragment ne se restaure jamais, il n'a donc
# aucune valeur à conserver ; et ce délai met hors d'atteinte le `.part` de la
# sauvegarde EN COURS, qu'une purge trop pressée détruirait sous ses pieds.
# Le motif attrape aussi le `.part.err` qui l'accompagne.
#
# Celle-ci reste INCONDITIONNELLE, contrairement à la rétention ci-dessus, et
# la raison est la même dans les deux cas : ne jamais détruire ce qui pourrait
# se restaurer. Un fragment ne le peut pas — le purger ne libère que de la
# place. C'est même sur un environnement EN PANNE qu'il faut le faire : le
# disque plein, cause fréquente de l'échec, se soigne en partie ici.
PART_RETENTION_DAYS=1
for env_name in "${TARGETS[@]}"; do
  purge_older_than "$PART_RETENTION_DAYS" "${env_name}-*.dump.part*"
done

[ "$purged" -gt 0 ] || info "aucun fichier à purger"

step "Bilan"
info "sauvegardes créées : $made (bases + instantanés de médias)"
info "environnements sautés : $skipped (absents ou jamais déployés)"
info "fichiers purgés    : $purged"
info "répertoire         : $BACKUP_DIR"

# L'ALERTE PART D'ICI, ET PAS DE CRON. Le commentaire qui occupait ces lignes
# affirmait « sous cron, c'est ce qui déclenche l'alerte » : c'était faux. Cron
# n'envoie un courriel que si le travail produit de la SORTIE, or la ligne de
# cron redirige tout vers `logger` ; il n'y a ni MAILTO ni MTA sur la machine.
# Le code de retour non nul reste juste et utile — il sert à qui appelle ce
# script à la main — mais il ne réveille personne. Voir _alert.sh.
if [ "$failures" -gt 0 ]; then
  alerte_signaler machine sauvegarde "Sauvegarde des bases: ECHEC" \
    "$failures environnement(s) déployé(s) n'ont PAS été sauvegardés." \
    "sauvegardes créées cette nuit : $made" \
    "répertoire : $BACKUP_DIR" \
    "" \
    "Une base non sauvegardée ne se découvre pas : elle se découvre le jour" \
    "de la restauration. Journal complet : journalctl -t carlys-backup -n 200"
  printf '\n%s✗ %s environnement(s) NON sauvegardé(s)%s\n' "$_c_red" "$failures" "$_c_off" >&2
  exit 1
fi

alerte_resoudre machine sauvegarde "Sauvegarde des bases: ECHEC"
