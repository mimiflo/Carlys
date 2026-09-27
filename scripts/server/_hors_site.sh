# shellcheck shell=bash
# La copie HORS MACHINE des sauvegardes — facultative, mais signalée tant
# qu'elle manque.
#
# LE DÉFAUT QUE CECI RÉPARE. Toutes les sauvegardes — dumps PostgreSQL et
# miroir MinIO avec ses instantanés — vivaient dans /srv/carlys/backups, sur
# le disque même qu'elles protègent. Disque mort, machine perdue chez
# l'hébergeur, rançongiciel, `rm -rf /srv/carlys` tapé de travers : les bases
# et leurs quatorze nuits d'historique disparaissaient ensemble. Pour une
# application qui garde des repas et des mesures corporelles, il ne restait
# aucune copie ailleurs (audit du 25/09).
#
# CE QUE FAIT backup.sh DÉSORMAIS, chaque nuit, APRÈS les sauvegardes locales
# et seulement si /srv/carlys/sauvegarde-distante.env est rempli (modèle :
# infrastructure/server/env/sauvegarde-distante.env.example) :
#
#   <bucket>/<préfixe>/<env>/postgres/<env>-<horodatage>.dump.gpg
#   <bucket>/<préfixe>/<env>/medias/medias-<horodatage>.tar.gpg
#
# puis, sur chaque sous-dossier qui vient de recevoir un envoi RÉUSSI, efface
# côté distant ce qui a plus de CARLYS_SAUVEGARDE_DISTANTE_RETENTION_JOURS.
# Même règle que la rétention locale : on ne jette l'ancien qu'après avoir
# posé le neuf.
#
# TOUTES LES VERSIONS, PAS SEULEMENT LA COURANTE (`mc rm --versions`). Sur un
# bucket versionné — ou verrouillé, ce qui l'impose —, un `mc rm` simple ne
# pose qu'un marqueur de suppression et rend 0 : le dump reste lisible par
# son identifiant de version, sans limite, comptes supprimés compris, alors
# que docs/legal/privacy.md promet 16 jours au plus « dans la copie de
# secours hors du serveur ». Sur un bucket sans versions, `--versions` efface
# exactement ce qu'effaçait le `mc rm` simple. Un verrou plus long que la
# rétention fait ÉCHOUER l'effacement, donc l'envoi, donc l'alerte « Copie
# hors machine » : la promesse rompue se voit, elle ne se tait plus.
#
# CHIFFRÉ AVANT DE PARTIR, ET PAR gpg. Le fournisseur distant ne doit rien
# pouvoir lire. gpg plutôt qu'`openssl enc`, pour trois raisons : gpg
# AUTHENTIFIE ce qu'il chiffre (un fichier altéré ou tronqué refuse de se
# déchiffrer, là où `openssl enc` en CBC rend des octets faux sans rien dire) ;
# son format OpenPGP est stable et se relit par n'importe quel gpg, des années
# plus tard, ce qui n'est pas vrai des options de dérivation d'`openssl enc`,
# qui ont changé de défaut entre les versions ; et il est déjà là — setup.sh
# installe `gnupg` (APT_BASE), présent de toute façon sur une Ubuntu serveur.
# Chiffrement SYMÉTRIQUE (AES-256) par une phrase de passe longue : une seule
# chose à garder hors de la machine, pas une paire de clés à gérer.
#
# LE TRANSFERT PASSE PAR `mc`, DANS L'IMAGE carlys-mc déjà tirée pour
# minio-init : aucun outil à installer sur l'hôte, aucune dépendance nouvelle.
# Les identifiants distants arrivent au conteneur par son ENTRÉE STANDARD,
# puis à `mc alias set` par un tube : ni l'hôte ni le conteneur ne les portent
# dans une ligne de commande (/proc/<pid>/cmdline est lisible par tous).
#
# Chargé par _common.sh. Aucun effet de bord au chargement.

hors_site_config_file() { printf '%s/sauvegarde-distante.env' "$CARLYS_ROOT"; }

hors_site_valeur() {
  local fichier
  fichier="$(hors_site_config_file)"
  [ -r "$fichier" ] || { printf '%s' "${2-}"; return 0; }
  env_value "$1" "$fichier" "${2-}"
}

# Les clés sans lesquelles rien ne part. Le préfixe et la rétention ont des
# défauts, pas celles-ci.
HORS_SITE_CLES_REQUISES="URL BUCKET CLE SECRET PHRASE"

# Une valeur restée à `CHANGE_MOI` (le modèle recopié tel quel) compte comme
# absente : mieux vaut que doctor la nomme qu'une nuit passée à envoyer vers
# s3.CHANGE_MOI.example.
hors_site_manquantes() {
  local cle valeur manque=''
  for cle in $HORS_SITE_CLES_REQUISES; do
    valeur="$(hors_site_valeur "CARLYS_SAUVEGARDE_DISTANTE_$cle" '')"
    case "$valeur" in
      '' | *CHANGE_MOI*) manque="$manque CARLYS_SAUVEGARDE_DISTANTE_$cle" ;;
    esac
  done
  printf '%s' "${manque# }"
}

hors_site_configuree() { [ -z "$(hors_site_manquantes)" ]; }

# Un préfixe par machine : deux serveurs qui partageraient un bucket ne
# s'écraseraient pas.
hors_site_prefixe() {
  hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_PREFIXE "$(hostname -s 2>/dev/null || printf 'carlys')"
}

hors_site_retention_jours() {
  local n
  n="$(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_RETENTION_JOURS "${CARLYS_BACKUP_RETENTION_DAYS:-14}")"
  case "$n" in '' | *[!0-9]*) n=14 ;; esac
  [ "$n" -ge 1 ] || n=1
  printf '%s' "$n"
}

# `hors_site_chiffrer <source|-> <cible>` — chiffre un fichier (ou l'entrée
# standard, avec « - ») en OpenPGP symétrique AES-256.
#
# La phrase passe par un descripteur (--passphrase-fd), jamais par la ligne de
# commande. Un GNUPGHOME jetable : rien dans le trousseau de root, et l'agent
# que gpg démarre est arrêté avec lui. `--compress-algo none` : un dump
# custom est déjà compressé, des photos aussi.
hors_site_chiffrer() {
  local source="$1" cible="$2" phrase gnupg rc=0 entree=()
  phrase="$(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_PHRASE '')"
  [ -n "$phrase" ] || { warn "phrase de chiffrement absente"; return 1; }
  [ "$source" = - ] || entree=("$source")
  gnupg="$(mktemp -d)"
  (
    umask 077
    GNUPGHOME="$gnupg" gpg --batch --yes --quiet --no-tty --pinentry-mode loopback \
      --passphrase-fd 3 --symmetric --cipher-algo AES256 --compress-algo none \
      --s2k-digest-algo SHA512 --s2k-count 65011712 \
      --output "$cible" "${entree[@]}" 3<<<"$phrase"
  ) || rc=$?
  GNUPGHOME="$gnupg" gpgconf --kill gpg-agent >/dev/null 2>&1 || true
  rm -rf "$gnupg"
  [ "$rc" -eq 0 ] || rm -f "$cible"
  return "$rc"
}

# Le script qui tourne DANS le conteneur carlys-mc (sh d'Alpine).
#   $1 URL S3   $2 cible (bucket/préfixe/env)   $3 jours de rétention
#   $4…  sous-dossiers à élaguer (ceux qui viennent de recevoir un envoi)
# Entrée standard : la clé d'accès, puis le secret, une ligne chacun.
#
# La taille relue côté distant (`mc stat`) doit égaler celle du fichier
# local : un envoi interrompu qui aurait laissé un objet partiel est un échec,
# pas un succès silencieux.
# shellcheck disable=SC2016 # développé par le shell DU CONTENEUR
HORS_SITE_SCRIPT='
set -eu
IFS= read -r cle
IFS= read -r secret
printf "%s\n%s\n" "$cle" "$secret" | mc alias set distant "$1" >/dev/null
unset cle secret
cible="distant/$2"
jours="$3"
shift 3
for f in /envoi/*; do
  [ -f "$f" ] || continue
  nom="${f##*/}"
  case "$nom" in
    *.dump.gpg) sous=postgres ;;
    *.tar.gpg) sous=medias ;;
    *) continue ;;
  esac
  mc cp --quiet "$f" "$cible/$sous/$nom" >/dev/null
  locale="$(wc -c < "$f" | tr -d " ")"
  distante="$(mc stat --json "$cible/$sous/$nom" | sed -n "s/.*\"size\":\([0-9]*\).*/\1/p" | head -n 1)"
  if [ "$locale" != "$distante" ]; then
    echo "taille distante (${distante:-inconnue}) différente de la locale ($locale) : $sous/$nom" >&2
    exit 1
  fi
  echo "envoyé : $sous/$nom ($locale octets)"
done
for sous in "$@"; do
  mc rm --recursive --force --versions --older-than "${jours}d" "$cible/$sous/" >/dev/null
done
'

# `hors_site_envoyer <env> <.env> <dossier d'envoi> [sous-dossiers à élaguer…]`
hors_site_envoyer() {
  local env_name="$1" file="$2" envoi="$3"; shift 3
  local cible
  cible="$(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_BUCKET '')/$(hors_site_prefixe)/$env_name"
  # `--no-deps` : aucun service à démarrer, seulement l'image de mc.
  printf '%s\n%s\n' \
    "$(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_CLE '')" \
    "$(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_SECRET '')" \
    | dc "$env_name" "$file" run --rm -T --no-deps \
      -v "$envoi:/envoi:ro" \
      --entrypoint /bin/sh minio-init -c "$HORS_SITE_SCRIPT" \
      hors-site "$(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_URL '')" "$cible" \
      "$(hors_site_retention_jours)" "$@"
}

# `hors_site_exporter <env> <.env> <dump ou vide> <miroir « courant » ou vide> <horodatage>`
#
# Chiffre ce qui a été produit cette nuit, l'envoie, élague ce qui a réussi.
# Rend 1 au premier échec — le message dit lequel. Le dossier d'envoi ne
# garde jamais rien : les fichiers chiffrés n'existent que le temps du
# transfert.
hors_site_exporter() {
  local env_name="$1" file="$2" dump="$3" miroir="$4" stamp="$5" envoi rc=0
  local sous=()
  envoi="$(backups_dir)/.hors-site-envoi"
  rm -rf "$envoi"
  mkdir -p "$envoi"
  chmod 700 "$envoi"

  if [ -n "$dump" ]; then
    if hors_site_chiffrer "$dump" "$envoi/$(basename -- "$dump").gpg"; then
      sous+=(postgres)
    else
      warn "$env_name : chiffrement du dump impossible, rien n'est parti"
      rc=1
    fi
  fi
  if [ -n "$miroir" ]; then
    # Une archive par nuit du miroir complet : restaurer, c'est UN fichier à
    # rapatrier. Le jour où le bucket pèsera des gigaoctets, un envoi
    # incrémental remplacera celui-ci — pas avant d'en avoir mesuré le besoin.
    if tar -C "$miroir" -cf - . | hors_site_chiffrer - "$envoi/medias-${stamp}.tar.gpg"; then
      sous+=(medias)
    else
      warn "$env_name : archive chiffrée des médias impossible, elle n'est pas partie"
      rc=1
    fi
  fi

  if [ "${#sous[@]}" -gt 0 ]; then
    if ! hors_site_envoyer "$env_name" "$file" "$envoi" "${sous[@]}"; then
      warn "$env_name : l'envoi vers $(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_URL '') a échoué (voir ci-dessus)"
      rc=1
    fi
  fi
  rm -rf "$envoi"
  return "$rc"
}

# Pour `carlysctl doctor`. Rend 1 si la PRODUCTION est déployée sans copie
# distante — un avertissement qui revient à chaque `doctor` tant que la cible
# n'est pas posée, et qui compte comme « il manque des choses ».
hors_site_doctor() {
  local derniere age
  if hors_site_configuree; then
    ok "copie hors machine : $(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_URL '') → $(hors_site_valeur CARLYS_SAUVEGARDE_DISTANTE_BUCKET '')/$(hors_site_prefixe), chiffrée (gpg)"
    if ! command -v gpg >/dev/null 2>&1; then
      warn "  gpg ABSENT : rien ne peut être chiffré, donc rien ne part. sudo apt-get install -y gnupg"
      return 1
    fi
    derniere="$(state_get machine sauvegarde_distante_derniere 0)"
    if [ "$derniere" -eq 0 ]; then
      warn "  aucun envoi réussi à ce jour. Le prochain passe cette nuit ; l'essayer tout de suite :"
      warn "    sudo $CARLYS_LIB_DIR/backup.sh"
    else
      age=$(( $(maintenant) - derniere ))
      if [ "$age" -gt $((2 * 86400)) ]; then
        warn "  dernier envoi réussi il y a $(status_duree "$age") : la copie distante vieillit"
        return 1
      fi
      ok "  dernier envoi réussi il y a $(status_duree "$age")"
    fi
    return 0
  fi

  warn "AUCUNE copie hors machine : les sauvegardes vivent sur le disque qu'elles protègent."
  warn "  Une panne de ce disque emporterait les bases ET leurs sauvegardes."
  warn "  Poser la cible dans $(hors_site_config_file), modèle :"
  warn "  $CARLYS_REPO_DIR/infrastructure/server/env/sauvegarde-distante.env.example"
  [ -r "$(hors_site_config_file)" ] && warn "  clé(s) manquante(s) : $(hors_site_manquantes)"
  if [ -n "$(deployed_current production)" ]; then
    warn "  La production est DÉPLOYÉE : ses données n'ont aucune copie ailleurs."
    return 1
  fi
  return 0
}
