#!/usr/bin/env bash
# Tests : sauvegarde d'avant-migration (deploy.sh), copie chiffrée hors
# machine (backup.sh, _hors_site.sh) et son avertissement dans doctor.
#
#   bash scripts/server/tests/sauvegarde_test.sh
#
# Sans Docker ni serveur (voir lib.sh). La partie « hors machine » demande de
# vrais binaires minio et mc (CARLYS_TEST_MINIO_BIN, ~/.carlys-minio ou le
# PATH) et gpg ; sans eux, elle est SAUTÉE et le dit — sauf sous
# CARLYS_TEST_EXIGER_MINIO=oui (la CI), où c'est un échec.
#
# Les `ls` de ce fichier ne lisent que des noms fabriqués par le banc lui-même.
# shellcheck disable=SC2012
set -euo pipefail

# shellcheck source=scripts/server/tests/lib.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
DEPLOY="${CARLYS_TEST_DEPLOY:-$BANC_SERVEUR/deploy.sh}"
BACKUP="${CARLYS_TEST_BACKUP:-$BANC_SERVEUR/backup.sh}"
CARLYSCTL="${CARLYS_TEST_CARLYSCTL:-$BANC_SERVEUR/carlysctl}"
trap banc_nettoyer EXIT

SHA_AVANT=aaaaaaaaaaaa
SHA=bbbbbbbbbbbb

echo "deploy.sh — sauvegarde d'avant-migration"

banc_preparer
banc_deployer production "$SHA_AVANT"
code="$(banc_lancer bash "$DEPLOY" production "$SHA")"
verifier "production : la migration (factice, en échec) arrête le déploiement" 1 "$code"
dump_rang="$(banc_rang 'exec -T postgres sh -c')"
migre_rang="$(banc_rang 'run --rm migrate')"
[ "$dump_rang" -gt 0 ] && [ "$migre_rang" -gt "$dump_rang" ] && ordre=dump-puis-migration || ordre="dump=$dump_rang migration=$migre_rang"
verifier "production : le dump précède la migration" dump-puis-migration "$ordre"
dumps=("$CARLYS_ROOT"/backups/avant-migration-production-*-"$SHA".dump)
if [ -f "${dumps[0]}" ]; then
  verifier "production : le dump porte le sha déployé" "PGDMP" "$(head -c 5 "${dumps[0]}")"
else
  verifier "production : le dump porte le sha déployé" "un fichier" "rien"
fi
verifier "production : le dump n'est lisible que par root" 600 "$(stat -c %a "${dumps[0]}" 2>/dev/null || echo absent)"
banc_nettoyer

banc_preparer
banc_deployer production "$SHA_AVANT"
FAUX_PG_DUMP=echec code="$(FAUX_PG_DUMP=echec banc_lancer bash "$DEPLOY" production "$SHA")"
verifier "dump en échec : déploiement interrompu" 1 "$code"
verifier "dump en échec : AUCUNE migration lancée" 0 "$(banc_rang 'run --rm migrate')"
grep -q "sauvegarde d'avant-migration a échoué" "$BANC_SORTIE" && dit=oui || dit=non
verifier "dump en échec : le message le dit" oui "$dit"
restes="$(find "$CARLYS_ROOT/backups" -name '*.part*' 2>/dev/null | wc -l || true)"
verifier "dump en échec : aucun fragment laissé" 0 "$restes"
banc_nettoyer

banc_preparer
banc_deployer production "$SHA_AVANT"
code="$(FAUX_PG_DUMP=vide banc_lancer bash "$DEPLOY" production "$SHA")"
verifier "dump sans signature PGDMP : refusé, aucune migration" "1 0" "$code $(banc_rang 'run --rm migrate')"
banc_nettoyer

banc_preparer
banc_deployer staging "$SHA_AVANT"
code="$(banc_lancer bash "$DEPLOY" staging "$SHA")"
verifier "recette : pas de dump par défaut" 0 "$(banc_rang 'exec -T postgres sh -c')"
verifier "recette : la migration est bien atteinte" 1 "$([ "$(banc_rang 'run --rm migrate')" -gt 0 ] && echo 1 || echo 0)"
code="$(CARLYS_DEPLOY_BACKUP=oui banc_lancer bash "$DEPLOY" staging "$SHA")"
verifier "recette avec CARLYS_DEPLOY_BACKUP=oui : dump fait" 1 "$(find "$CARLYS_ROOT/backups" -name 'avant-migration-staging-*' 2>/dev/null | wc -l || true)"
banc_nettoyer

banc_preparer
code="$(banc_lancer bash "$DEPLOY" production "$SHA")"
verifier "premier déploiement : pas de dump (rien à protéger)" 0 "$(banc_rang 'exec -T postgres sh -c')"
banc_nettoyer

banc_preparer
banc_deployer production "$SHA_AVANT"
echo 'CARLYS_DEPLOY_BACKUP=non' >> "$CARLYS_ROOT/production/.env"
code="$(banc_lancer bash "$DEPLOY" production "$SHA")"
verifier "production, CARLYS_DEPLOY_BACKUP=non dans le .env : pas de dump" 0 "$(banc_rang 'exec -T postgres sh -c')"
sed -i 's/^CARLYS_DEPLOY_BACKUP=non$/CARLYS_DEPLOY_BACKUP=nnon/' "$CARLYS_ROOT/production/.env"
code="$(banc_lancer bash "$DEPLOY" production "$SHA")"
verifier "production, valeur mal orthographiée : dump fait quand même (faille fermée)" 1 "$([ "$(banc_rang 'exec -T postgres sh -c')" -gt 0 ] && echo 1 || echo 0)"
banc_nettoyer

banc_preparer
banc_deployer production "$SHA_AVANT"
mkdir -p "$CARLYS_ROOT/backups"
for h in 20260101T000000Z 20260102T000000Z 20260103T000000Z 20260104T000000Z; do
  printf 'PGDMP' > "$CARLYS_ROOT/backups/avant-migration-production-$h-cccccccccccc.dump"
done
printf 'PGDMP' > "$CARLYS_ROOT/backups/production-20260101T000000Z.dump"
code="$(banc_lancer bash "$DEPLOY" production "$SHA")"
restants="$(find "$CARLYS_ROOT/backups" -maxdepth 1 -name 'avant-migration-production-*.dump' -printf '%f\n' 2>/dev/null | sort | tr '\n' ' ' || true)"
case "$restants" in
  *20260103T000000Z*20260104T000000Z*"$SHA".dump*) garde=les-3-plus-recents ;;
  *) garde="$restants" ;;
esac
verifier "rétention : les 3 derniers dumps d'avant-migration, dont le neuf" "3 les-3-plus-recents" \
  "$(printf '%s' "$restants" | wc -w) $garde"
verifier "rétention : la sauvegarde nocturne n'est pas touchée" 1 "$(ls "$CARLYS_ROOT"/backups/production-*.dump 2>/dev/null | wc -l || true)"
banc_nettoyer

# L'âge maximal : sans lui, un trimestre sans déploiement gardait des dumps
# de huit mois, avec des comptes que la purge a effacés de la base depuis.
vieux_dumps() {
  mkdir -p "$CARLYS_ROOT/backups"
  local h
  for h in 20260101T000000Z 20260201T000000Z; do
    printf 'PGDMP' > "$CARLYS_ROOT/backups/avant-migration-production-$h-cccccccccccc.dump"
    touch -d '200 days ago' "$CARLYS_ROOT/backups/avant-migration-production-$h-cccccccccccc.dump"
  done
  printf 'PGDMP' > "$CARLYS_ROOT/backups/avant-migration-production-20260901T000000Z-dddddddddddd.dump"
  touch -d '10 days ago' "$CARLYS_ROOT/backups/avant-migration-production-20260901T000000Z-dddddddddddd.dump"
}
avant_migration_restants() {
  find "$CARLYS_ROOT/backups" -maxdepth 1 -name 'avant-migration-production-*.dump' -printf '%f\n' 2>/dev/null \
    | sed 's/^avant-migration-production-[0-9TZ]*-//; s/\.dump$//' | sort | tr '\n' ' ' || true
}

banc_preparer
banc_deployer production "$SHA_AVANT"
vieux_dumps
code="$(banc_lancer bash "$DEPLOY" production "$SHA")"
verifier "rétention au déploiement : plus vieux que 30 jours purgés, le récent et le neuf gardés" \
  "$SHA dddddddddddd " "$(avant_migration_restants)"
banc_nettoyer

banc_preparer
banc_deployer production "$SHA_AVANT"
vieux_dumps
code="$(FAUX_SERVICES=postgres banc_lancer bash "$BACKUP" production)"
verifier "rétention CHAQUE NUIT, sans déploiement : les dumps de 200 jours sont purgés" \
  "dddddddddddd " "$(avant_migration_restants)"
banc_nettoyer

banc_preparer
banc_deployer production "$SHA_AVANT"
vieux_dumps
code="$(FAUX_PG_DUMP=echec FAUX_SERVICES=postgres banc_lancer bash "$BACKUP" production)"
verifier "nuit sans dump neuf : rien n'est purgé (règle de backup.sh)" \
  "cccccccccccc cccccccccccc dddddddddddd " "$(avant_migration_restants)"
banc_nettoyer

banc_preparer
banc_deployer production "$SHA_AVANT"
vieux_dumps
echo 'CARLYS_BACKUP_PREMIGRATION_MAX_DAYS=5' >> "$CARLYS_ROOT/production/.env"
code="$(FAUX_SERVICES=postgres banc_lancer bash "$BACKUP" production)"
verifier "CARLYS_BACKUP_PREMIGRATION_MAX_DAYS lu dans le .env : 10 jours, c'est trop" \
  "" "$(avant_migration_restants)"
banc_nettoyer

# Horloge reculée : un dump au nom « plus récent » que le neuf. Avec N=1, la
# borne du nombre désignerait le neuf — il est gardé quand même.
banc_preparer
banc_deployer production "$SHA_AVANT"
mkdir -p "$CARLYS_ROOT/backups"
printf 'PGDMP' > "$CARLYS_ROOT/backups/avant-migration-production-20991231T000000Z-eeeeeeeeeeee.dump"
code="$(CARLYS_BACKUP_PREMIGRATION_KEEP=1 banc_lancer bash "$DEPLOY" production "$SHA")"
verifier "le dump qu'on vient d'écrire n'est jamais purgé, quelles que soient les bornes" \
  "$SHA eeeeeeeeeeee " "$(avant_migration_restants)"
banc_nettoyer

echo
echo "backup.sh — copie hors machine"

# Sans MinIO dans ce cas-ci (le miroir des médias échoue, et c'est lui seul
# qui fait sortir en erreur) : on juge la copie distante, rien d'autre.
banc_preparer
banc_deployer production "$SHA_AVANT"
code="$(FAUX_SERVICES=postgres banc_lancer bash "$BACKUP" production)"
grep -q "AUCUNE copie hors machine" "$BANC_SORTIE" && dit=oui || dit=non
verifier "sans cible distante, production déployée : avertissement" oui "$dit"
grep -q '^alerte_sauvegarde_distante_etat=' "$CARLYS_ROOT/machine/orchestrateur.etat" 2>/dev/null && alerte=oui || alerte=non
verifier "sans cible distante : ce n'est pas une panne (facultative, aucune alerte)" non "$alerte"
banc_nettoyer

if ! command -v gpg >/dev/null 2>&1; then
  sauter "copie hors machine : gpg absent"
else
  banc_preparer
  if ! banc_binaires_minio; then
    sauter "copie hors machine : binaires minio et mc introuvables"
  else
    banc_demarrer_minio
    mc mb --ignore-existing banc/carlys-media >/dev/null
    printf 'photo-de-banc' > "$BANC/photo.png"
    mc cp --quiet "$BANC/photo.png" banc/carlys-media/exercices/photo.png >/dev/null
    mc mb --ignore-existing banc/carlys-sauvegardes >/dev/null
    banc_deployer production "$SHA_AVANT"
    PHRASE='une phrase de passe de banc, longue et unique'
    cat > "$CARLYS_ROOT/sauvegarde-distante.env" <<FIN
CARLYS_SAUVEGARDE_DISTANTE_URL=$FAUX_MINIO_URL
CARLYS_SAUVEGARDE_DISTANTE_BUCKET=carlys-sauvegardes
CARLYS_SAUVEGARDE_DISTANTE_PREFIXE=banc
CARLYS_SAUVEGARDE_DISTANTE_CLE=$MINIO_ROOT_USER
CARLYS_SAUVEGARDE_DISTANTE_SECRET=$MINIO_ROOT_PASSWORD
CARLYS_SAUVEGARDE_DISTANTE_PHRASE=$PHRASE
FIN
    code="$(banc_lancer bash "$BACKUP" production)"
    verifier "cible distante posée : la nuit est un succès" 0 "$code"
    objets="$(mc ls --recursive banc/carlys-sauvegardes/banc/production/ 2>/dev/null | awk '{print $NF}' | sort | tr '\n' ' ' || true)"
    case "$objets" in
      *"medias/medias-"*".tar.gpg"*"postgres/production-"*".dump.gpg"*) envoyes=dump-et-medias ;;
      *) envoyes="$objets" ;;
    esac
    verifier "le dump et l'archive des médias sont partis" dump-et-medias "$envoyes"

    distant_dump="$(mc ls banc/carlys-sauvegardes/banc/production/postgres/ 2>/dev/null | awk '{print $NF}' | head -n 1 || true)"
    mc cp --quiet "banc/carlys-sauvegardes/banc/production/postgres/$distant_dump" "$BANC/rapatrie.gpg" >/dev/null 2>&1 || : > "$BANC/rapatrie.gpg"
    verifier "l'objet distant n'est pas lisible en clair" non "$([ "$(head -c 5 "$BANC/rapatrie.gpg")" = PGDMP ] && echo oui || echo non)"
    local_dump="$(ls "$CARLYS_ROOT"/backups/production-*.dump 2>/dev/null | head -n 1 || true)"
    GNUPGHOME="$BANC/gnupg"; mkdir -m 700 "$GNUPGHOME"; export GNUPGHOME
    gpg --batch --quiet --pinentry-mode loopback --passphrase "$PHRASE" --decrypt \
      --output "$BANC/rapatrie.dump" "$BANC/rapatrie.gpg" 2>/dev/null || true
    verifier "restauration : gpg --decrypt rend le dump de la nuit, octet pour octet" oui \
      "$(cmp -s "$BANC/rapatrie.dump" "$local_dump" && echo oui || echo non)"
    distant_medias="$(mc ls banc/carlys-sauvegardes/banc/production/medias/ 2>/dev/null | awk '{print $NF}' | head -n 1 || true)"
    mc cp --quiet "banc/carlys-sauvegardes/banc/production/medias/$distant_medias" "$BANC/medias.gpg" >/dev/null 2>&1 || : > "$BANC/medias.gpg"
    mkdir -p "$BANC/medias"
    gpg --batch --quiet --pinentry-mode loopback --passphrase "$PHRASE" --decrypt "$BANC/medias.gpg" 2>/dev/null \
      | tar -C "$BANC/medias" -xf - 2>/dev/null || true
    verifier "restauration : l'archive des médias rend la photo" photo-de-banc \
      "$(cat "$BANC/medias/exercices/photo.png" 2>/dev/null || echo absente)"
    verifier "mauvaise phrase : le déchiffrement échoue" echec \
      "$(GNUPGHOME="$BANC/gnupg" gpg --batch --quiet --pinentry-mode loopback --passphrase faux \
        --decrypt "$BANC/rapatrie.gpg" >/dev/null 2>&1 && echo reussi || echo echec)"
    gpgconf --kill gpg-agent >/dev/null 2>&1 || true
    unset GNUPGHOME
    verifier "rien de chiffré ne reste sur le disque local" 0 \
      "$(find "$CARLYS_ROOT/backups" -name '*.gpg' 2>/dev/null | wc -l || true)"
    grep -q "$MINIO_ROOT_PASSWORD" "$FAUX_JOURNAL" && fuite=oui || fuite=non
    verifier "le secret distant n'apparaît dans aucune ligne de commande" non "$fuite"
    verifier "doctor : copie configurée et récente → rien à signaler" 0 \
      "$(bash -c ". '$BANC_SERVEUR/_common.sh'; hors_site_doctor" > "$BANC_SORTIE" 2>&1 && echo 0 || echo 1)"

    # La rétention sur un bucket VERSIONNÉ (ou verrouillé, ce qui l'impose).
    # Un `mc rm` sans --versions n'y pose qu'un marqueur de suppression : le
    # dump reste lisible par son identifiant de version, sans limite de
    # durée, comptes supprimés compris — contre les 16 jours que promet
    # docs/legal/privacy.md. Le script du conteneur est joué directement,
    # avec 0 jour de rétention : le banc ne sait pas vieillir un objet.
    mc mb --ignore-existing banc/carlys-versionne >/dev/null
    mc version enable banc/carlys-versionne >/dev/null
    printf 'dump-avec-un-compte-supprime' > "$BANC/vieux.dump.gpg"
    mc cp --quiet "$BANC/vieux.dump.gpg" banc/carlys-versionne/banc/production/postgres/vieux.dump.gpg >/dev/null
    sleep 1
    printf '%s\n%s\n' "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" \
      | bash -c '. "$0/_common.sh"; sh -c "$HORS_SITE_SCRIPT" hors-site "$1" carlys-versionne/banc/production 0 postgres' \
        "$BANC_SERVEUR" "$FAUX_MINIO_URL" > "$BANC_SORTIE" 2>&1 && code=0 || code=$?
    verifier "bucket versionné : la rétention passe" 0 "$code"
    verifier "bucket versionné : le vieux dump n'existe plus, AUCUNE version" "" \
      "$(mc ls --versions --recursive banc/carlys-versionne/banc/production/ 2>/dev/null || true)"
    # Un verrou d'objets plus long que la rétention : l'effacement est
    # impossible, et cela doit se VOIR (échec, donc alerte), pas se taire.
    mc mb --ignore-existing --with-lock banc/carlys-verrouille >/dev/null
    mc retention set --default COMPLIANCE 1d banc/carlys-verrouille >/dev/null
    mc cp --quiet "$BANC/vieux.dump.gpg" banc/carlys-verrouille/banc/production/postgres/vieux.dump.gpg >/dev/null
    sleep 1
    printf '%s\n%s\n' "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" \
      | bash -c '. "$0/_common.sh"; sh -c "$HORS_SITE_SCRIPT" hors-site "$1" carlys-verrouille/banc/production 0 postgres' \
        "$BANC_SERVEUR" "$FAUX_MINIO_URL" > "$BANC_SORTIE" 2>&1 && code=0 || code=$?
    verifier "verrou plus long que la rétention : la rétention ÉCHOUE (donc l'envoi, donc l'alerte)" 1 "$code"

    # Un fournisseur qui refuse : la nuit échoue, avec SA propre alerte, et la
    # sauvegarde locale est là quand même.
    sed -i 's/^CARLYS_SAUVEGARDE_DISTANTE_SECRET=.*/CARLYS_SAUVEGARDE_DISTANTE_SECRET=faux-secret/' \
      "$CARLYS_ROOT/sauvegarde-distante.env"
    avant="$(ls "$CARLYS_ROOT"/backups/production-*.dump 2>/dev/null | wc -l || true)"
    sleep 1
    code="$(banc_lancer bash "$BACKUP" production)"
    verifier "fournisseur qui refuse : la nuit sort en erreur" 1 "$code"
    verifier "fournisseur qui refuse : le dump local de la nuit existe" "$((avant + 1))" \
      "$(ls "$CARLYS_ROOT"/backups/production-*.dump 2>/dev/null | wc -l || true)"
    verifier "fournisseur qui refuse : alerte « copie hors machine » en panne" panne \
      "$(grep '^alerte_sauvegarde_distante_etat=' "$CARLYS_ROOT/machine/orchestrateur.etat" | cut -d= -f2)"
    verifier "fournisseur qui refuse : l'alerte des BASES reste saine" sain \
      "$(grep '^alerte_sauvegarde_etat=' "$CARLYS_ROOT/machine/orchestrateur.etat" | cut -d= -f2 || true)$(grep -q '^alerte_sauvegarde_etat=' "$CARLYS_ROOT/machine/orchestrateur.etat" || echo sain)"
  fi
  banc_nettoyer
fi

echo
echo "doctor — l'avertissement tant que la production n'a pas de copie distante"
banc_preparer
doctor() { bash -c ". '$BANC_SERVEUR/_common.sh'; hors_site_doctor" > "$BANC_SORTIE" 2>&1 && echo 0 || echo 1; }
verifier "rien de déployé, pas de cible : avertit sans compter comme un manque" 0 "$(doctor)"
grep -q "AUCUNE copie hors machine" "$BANC_SORTIE" && dit=oui || dit=non
verifier "… mais le dit" oui "$dit"
banc_deployer production "$SHA_AVANT"
verifier "production déployée, pas de cible : il manque quelque chose" 1 "$(doctor)"
code="$(banc_lancer bash "$CARLYSCTL" doctor)"
grep -q "AUCUNE copie hors machine" "$BANC_SORTIE" && dit=oui || dit=non
verifier "carlysctl doctor le dit, à chaque passage" oui "$dit"
printf 'CARLYS_SAUVEGARDE_DISTANTE_URL=https://s3.exemple\n' > "$CARLYS_ROOT/sauvegarde-distante.env"
doctor > /dev/null
grep -q "CARLYS_SAUVEGARDE_DISTANTE_PHRASE" "$BANC_SORTIE" && dit=oui || dit=non
verifier "cible incomplète : les clés manquantes sont nommées" oui "$dit"
cp "$BANC_SERVEUR/../../infrastructure/server/env/sauvegarde-distante.env.example" "$CARLYS_ROOT/sauvegarde-distante.env"
verifier "modèle recopié sans être rempli : pas configuré" 1 "$(doctor)"
banc_nettoyer

banc_bilan
