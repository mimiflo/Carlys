#!/usr/bin/env bash
# Tests : ce que la passe de supervision fait d'elle-même — avancer le clone
# du serveur (_repo.sh, repo_pull) et lancer les tâches quotidiennes
# (_quotidien.sh : balayage des photos, purge des comptes supprimés) ; et,
# de la même purge lancée à la main, l'adresse de `--compte-actif`.
#
#   bash scripts/server/tests/supervision_test.sh
#
# Sans Docker ni serveur (voir lib.sh) : un dépôt « origine » jetable tient
# lieu de GitHub, le docker factice tient lieu du registre et de l'image API.
set -euo pipefail

# shellcheck source=scripts/server/tests/lib.sh
. "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/lib.sh"
trap banc_nettoyer EXIT

# `appeler <fonction> <arguments…>` — une fonction des scripts serveur, dans
# un bash neuf qui charge _common.sh ; rend son code, garde sa sortie.
appeler() {
  # shellcheck disable=SC2016 # développé par le bash appelé, pas par celui-ci
  banc_lancer bash -o pipefail -c '. "$0/_common.sh"; "$@"' "$BANC_SERVEUR" "$@"
}

echo "repo_pull — le clone n'avance que jusqu'à un commit qui a passé la porte"

banc_preparer
git init -q --bare -b development "$BANC/origine.git"
git clone -q "$BANC/origine.git" "$BANC/travail" 2> /dev/null
pousser() {
  git -C "$BANC/travail" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "$1"
  git -C "$BANC/travail" push -q origin HEAD:development 2> /dev/null
  git -C "$BANC/travail" rev-parse HEAD
}
C1="$(pousser C1)"
git clone -q -b development "$BANC/origine.git" "$BANC/repo" 2> /dev/null
export CARLYS_REPO_DIR="$BANC/repo"
tete() { git -C "$BANC/repo" rev-parse HEAD; }

# Le scénario de l'audit : C2 ne touche que les scripts du serveur, infra-ci
# le rejette, images-publish ne pousse donc pas ses images.
C2="$(pousser C2)"
code="$(FAUX_IMAGES_ABSENTES="${C2:0:12}" appeler repo_pull)"
verifier "tête sans images (CI rouge ou en cours) : repo_pull rend 0" 0 "$code"
verifier "… et le clone RESTE sur le dernier commit qui avait passé la porte" "$C1" "$(tete)"
grep -q 'sans images publiées' "$BANC_SORTIE" && dit=oui || dit=non
verifier "… en le disant" oui "$dit"

# La CI est verte, les images existent : le clone avance.
code="$(appeler repo_pull)"
verifier "tête avec ses images : le clone avance jusqu'à elle" "0 $C2" "$code $(tete)"
code="$(appeler repo_pull)"
verifier "déjà à jour : rien à faire" "0 $C2" "$code $(tete)"

# Une modification locale n'est jamais écrasée.
C3="$(pousser C3)"
printf 'retouche\n' > "$BANC/repo/local.txt"
code="$(appeler repo_pull)"
verifier "modification locale : le clone n'est pas touché" "0 $C2" "$code $(tete)"
rm -f "$BANC/repo/local.txt"
code="$(appeler repo_pull)"
verifier "… puis, nettoyé, il avance" "0 $C3" "$code $(tete)"
banc_nettoyer
unset CARLYS_REPO_DIR

echo
echo "tâches quotidiennes — rythme, réessai dans l'heure, alerte"

# `etat <env> <clé>` — la valeur de l'état d'orchestration, ou « - ».
etat() { awk -F= -v k="$2" '$1 == k { v = $2 } END { print (v == "" ? "-" : v) }' \
  "$CARLYS_ROOT/$1/orchestrateur.etat" 2> /dev/null || echo -; }
lancements() { grep -c -F -- "node dist/cli/$1" "$FAUX_JOURNAL" || true; }
reculer() { # reculer <env> <clé> <secondes> — le dernier passage, plus tôt
  appeler state_set "$1" "$2" "$(($(date -u +%s) - $3))" > /dev/null
}

for tache in "photos_balayer_si_du balayage_photos meal-photos-sweep" \
             "purge_comptes_si_due purge_comptes deleted-accounts-purge"; do
  read -r fonction cle cli <<< "$tache"
  banc_preparer
  F="$CARLYS_ROOT/staging/.env"

  code="$(appeler "$fonction" staging "$F")"
  verifier "$cli : environnement jamais déployé → rien" "0 0" "$code $(lancements "$cli")"

  banc_deployer staging aaaaaaaaaaaa
  code="$(appeler "$fonction" staging "$F")"
  verifier "$cli : premier passage → lancé, réussi" "0 1 non" "$code $(lancements "$cli") $(etat staging "${cle}_echec")"
  code="$(appeler "$fonction" staging "$F")"
  verifier "$cli : passage suivant, le même jour → pas relancé" "0 1" "$code $(lancements "$cli")"

  reculer staging "$cle" $((25 * 3600))
  code="$(FAUX_CLI_CODE=1 appeler "$fonction" staging "$F")"
  verifier "$cli : le lendemain, échec → 1, alerte ouverte" "1 2 oui panne" \
    "$code $(lancements "$cli") $(etat staging "${cle}_echec") $(etat staging "alerte_${cle}_etat")"
  reculer staging "$cle" 1800
  code="$(appeler "$fonction" staging "$F")"
  verifier "$cli : 30 min après l'échec → pas encore relancé" "0 2" "$code $(lancements "$cli")"
  reculer staging "$cle" 3700
  code="$(appeler "$fonction" staging "$F")"
  verifier "$cli : une heure après l'échec → relancé, alerte résolue" "0 3 non sain" \
    "$code $(lancements "$cli") $(etat staging "${cle}_echec") $(etat staging "alerte_${cle}_etat")"

  reculer staging "$cle" $((25 * 3600))
  code="$(FAUX_CLI_ABSENTS="$cli" appeler "$fonction" staging "$F")"
  verifier "$cli : image antérieure à la commande → rien, sans erreur" "0 3" "$code $(lancements "$cli")"
  banc_nettoyer
done

# La purge seule : le délai du .env part au CLI.
banc_preparer
banc_deployer production aaaaaaaaaaaa
printf 'CARLYS_ACCOUNT_PURGE_DAYS=45\n' >> "$CARLYS_ROOT/production/.env"
appeler purge_comptes_si_due production "$CARLYS_ROOT/production/.env" > /dev/null
grep -q -F -- 'node dist/cli/deleted-accounts-purge --delai-jours 45' "$FAUX_JOURNAL" && passe=oui || passe=non
verifier "purge : CARLYS_ACCOUNT_PURGE_DAYS part au CLI (--delai-jours 45)" oui "$passe"
banc_nettoyer

echo
echo "purge à la main, --compte-actif — l'adresse se tape, jamais en argument"

# `effacer <adresse tapée> <arguments…>` — carlysctl deleted-accounts-purge
# production, l'adresse sur l'entrée standard ; rend le code de sortie.
effacer() {
  local tapee="$1" code=0; shift
  printf '%s' "$tapee" | bash "$BANC_SERVEUR/carlysctl" deleted-accounts-purge production "$@" \
    > "$BANC_SORTIE" 2>&1 || code=$?
  printf '%s' "$code"
}
UUID=11111111-2222-4333-8444-555555555555
banc_preparer
banc_deployer production aaaaaaaaaaaa
code="$(effacer $'  Membre@Exemple.fr \n' --compte-actif "$UUID" --a-blanc)"
grep -q -F -- "deleted-accounts-purge --compte-actif $UUID --a-blanc --confirmer Membre@Exemple.fr" \
  "$FAUX_JOURNAL" && passe=oui || passe=non
verifier "adresse tapée : elle part au CLI, espaces ôtés" "0 oui" "$code $passe"
: > "$FAUX_JOURNAL"
code="$(effacer '' --compte-actif "$UUID" --confirmer membre@exemple.fr)"
verifier "adresse en argument (l'historique du shell la garderait) : refus, rien lancé" "1 0" \
  "$code $(lancements deleted-accounts-purge)"
: > "$FAUX_JOURNAL"
code="$(effacer '' --compte-actif "$UUID")"
verifier "rien de tapé : refus, rien lancé" "1 0" "$code $(lancements deleted-accounts-purge)"
banc_nettoyer

echo
echo "configuration versionnée (ADR 0017) — couches, priorité, état"

lire() { appeler env_value "$@" > /dev/null; cat "$BANC_SORTIE"; }
banc_preparer
ENV_STAGING="$CARLYS_ROOT/staging/.env"
printf 'LOG_LEVEL=info\nCOACH_MODEL=commun\n' > "$CARLYS_CONFIG_DIR/commun.conf"
printf 'LOG_LEVEL=debug\nCARLYS_OLLAMA_REPLICAS=1\n' > "$CARLYS_CONFIG_DIR/staging.conf"
verifier "env_value : le fichier d'environnement l'emporte sur commun.conf" debug "$(lire LOG_LEVEL "$ENV_STAGING" x)"
verifier "env_value : commun.conf répond quand rien d'autre ne le dit" commun "$(lire COACH_MODEL "$ENV_STAGING" x)"
echo 'LOG_LEVEL=warn' >> "$ENV_STAGING"
verifier "env_value : le .env l'emporte encore (migration sans surprise)" warn "$(lire LOG_LEVEL "$ENV_STAGING" x)"
verifier "env_value : un fichier hors environnement n'a pas de couches" x \
  "$(printf 'A=1\n' > "$BANC/autre.env"; lire LOG_LEVEL "$BANC/autre.env" x)"
voulus() { appeler api_replicas_wanted staging "$ENV_STAGING" > /dev/null; cat "$BANC_SORTIE"; }
verifier "exemplaires : sans état ni plancher, un seul" 1 "$(voulus)"
printf 'CARLYS_SCALE_MIN=2\n' >> "$CARLYS_CONFIG_DIR/staging.conf"
verifier "exemplaires : jamais sous CARLYS_SCALE_MIN, même sans état" 2 "$(voulus)"
: > "$FAUX_JOURNAL"
appeler dc staging "$ENV_STAGING" up -d > /dev/null
verifier "… et c'est ce que Compose reçoit, pas seulement ce qui s'affiche" oui \
  "$(grep -q '^exemplaires-api=2$' "$FAUX_JOURNAL" && echo oui || echo non)"
verifier "… et « scale » refuse de descendre sous le plancher" 1 \
  "$(appeler scale_apply staging "$ENV_STAGING" 1)"
printf 'CARLYS_API_REPLICAS=4\n' > "$CARLYS_ROOT/staging/etat.env"
verifier "exemplaires : l'état au-dessus du plancher est gardé" 4 "$(voulus)"
rm -f "$CARLYS_ROOT/staging/etat.env"
: > "$FAUX_JOURNAL"
appeler dc staging "$ENV_STAGING" ps > /dev/null
verifier "dc : les couches dans l'ordre, le .env en dernier" \
  "--env-file $CARLYS_CONFIG_DIR/commun.conf --env-file $CARLYS_CONFIG_DIR/staging.conf --env-file $ENV_STAGING" \
  "$(grep -o -- '--env-file [^ ]*' "$FAUX_JOURNAL" | tr '\n' ' ' | sed 's/ $//')"
verifier "dc : le coach s'allume depuis staging.conf" oui "$(grep -q -F -- '--profile ollama' "$FAUX_JOURNAL" && echo oui || echo non)"
appeler env_set_tag "$ENV_STAGING" sha-aaaaaaaaaaaa > /dev/null
verifier "état : le .env qui porte CARLYS_TAG le garde là (sinon masqué)" sha-aaaaaaaaaaaa "$(grep '^CARLYS_TAG=' "$ENV_STAGING" | cut -d= -f2)"
sed -i '/^CARLYS_TAG=/d' "$ENV_STAGING"
appeler env_set_tag "$ENV_STAGING" sha-bbbbbbbbbbbb > /dev/null
verifier "état : sinon dans etat.env, créé à la volée" sha-bbbbbbbbbbbb "$(grep '^CARLYS_TAG=' "$CARLYS_ROOT/staging/etat.env" | cut -d= -f2)"
verifier "état : etat.env n'est lisible que par root" 600 "$(stat -c %a "$CARLYS_ROOT/staging/etat.env")"
verifier "état : relu par env_value" sha-bbbbbbbbbbbb "$(lire CARLYS_TAG "$ENV_STAGING" x)"
: > "$FAUX_JOURNAL"
appeler dc staging "$ENV_STAGING" ps > /dev/null
verifier "dc : etat.env entre l'environnement et le .env" oui \
  "$(grep -q -- "staging.conf --env-file $CARLYS_ROOT/staging/etat.env --env-file $ENV_STAGING" "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

echo
echo "configuration figée (ADR 0017) — celle du sha déployé, pas celle du clone"

banc_preparer
ENV_STAGING="$CARLYS_ROOT/staging/.env"
DEPOT="$BANC/depot"
git init -q -b development "$DEPOT"
git -C "$DEPOT" -c user.name=banc -c user.email=banc@banc commit -q --allow-empty -m "avant l'ADR"
ancien="$(git -C "$DEPOT" rev-parse --short=12 HEAD)"
mkdir -p "$DEPOT/infrastructure/server/config"
printf 'LOG_LEVEL=info\n' > "$DEPOT/infrastructure/server/config/commun.conf"
printf 'COACH_MODEL=version-deployee\n' > "$DEPOT/infrastructure/server/config/staging.conf"
git -C "$DEPOT" add -A && git -C "$DEPOT" -c user.name=banc -c user.email=banc@banc commit -q -m config
deploye="$(git -C "$DEPOT" rev-parse --short=12 HEAD)"
# Le clone a AVANCÉ depuis (la supervision le fait seule) : ce n'est pas lui
# que la pile doit lire.
printf 'COACH_MODEL=pousse-mais-pas-deploye\n' > "$DEPOT/infrastructure/server/config/staging.conf"
export CARLYS_REPO_DIR="$DEPOT" CARLYS_CONFIG_DIR="$DEPOT/infrastructure/server/config"
verifier "avant tout gel : la configuration du clone" pousse-mais-pas-deploye "$(lire COACH_MODEL "$ENV_STAGING" x)"
appeler config_figer staging "$deploye" > /dev/null
verifier "figée : celle du commit déployé, pas celle du clone" version-deployee "$(lire COACH_MODEL "$ENV_STAGING" x)"
: > "$FAUX_JOURNAL"; appeler dc staging "$ENV_STAGING" ps > /dev/null
verifier "dc : compose lit la configuration figée" oui \
  "$(grep -q -- "--env-file $CARLYS_ROOT/staging/config/staging.conf" "$FAUX_JOURNAL" && echo oui || echo non)"
appeler config_rendre staging > /dev/null
verifier "rendue (bascule ratée) : retour à la configuration d'avant, le clone ici" pousse-mais-pas-deploye "$(lire COACH_MODEL "$ENV_STAGING" x)"
appeler config_figer staging "$deploye" > /dev/null
verifier "un commit d'avant l'ADR : refusé (code 1)…" 1 "$(appeler config_figer staging "$ancien")"
verifier "… et la configuration en service est gardée" version-deployee "$(lire COACH_MODEL "$ENV_STAGING" x)"
verifier "un sha inconnu du clone : même chose" 1 "$(appeler config_figer staging 0123456789ab)"
banc_nettoyer
unset CARLYS_REPO_DIR

echo
echo "config-migrer (ADR 0017) — le .env réduit à ses secrets, rien ne change"

banc_preparer
ENV_STAGING="$CARLYS_ROOT/staging/.env"
# Un .env d'AVANT l'ADR, tel que l'ancien gabarit le donnait : réglages,
# état et secrets dans un seul fichier, remplis comme sur un serveur, avec un
# réglage qu'on y avait changé à la main.
DEPOT_CONFIG="$BANC_SERVEUR/../../infrastructure/server"
cp "$DEPOT_CONFIG/config/"*.conf "$CARLYS_CONFIG_DIR/"
{ cat "$DEPOT_CONFIG/config/commun.conf" "$DEPOT_CONFIG/config/staging.conf"
  printf 'CARLYS_TAG=sha-123456789abc\nCARLYS_API_REPLICAS=1\n'
  cat "$DEPOT_CONFIG/env/staging.env.example"
} | sed -e 's/=CHANGE_MOI_[A-Z0-9_]*/=secret-du-banc-0123456789abcdef0123/' -e 's/^LOG_LEVEL=.*/LOG_LEVEL=info/' \
      -e 's/^SWAGGER_ENABLED=.*/SWAGGER_ENABLED=true/' \
  > "$ENV_STAGING"
echo 'CARLYS_OLLAMA_REPLICAS=1' >> "$ENV_STAGING"
# Assemblée ici, jamais écrite d'un bloc : le détecteur de secrets de la CI
# (TruffleHog) prendrait l'adresse factice pour un vrai identifiant.
identifiant='nom:motdepasse'
printf 'COACH_WORKER_URLS=https://%s@gpu.exemple/v1\n' "$identifiant" >> "$ENV_STAGING"
mkdir -p "$BANC/exemples"
cp "$DEPOT_CONFIG/env/staging.env.example" "$BANC/exemples/"
export CARLYS_ENV_EXAMPLES_DIR="$BANC/exemples"
avant="$BANC/avant.env"; cp "$ENV_STAGING" "$avant"
cles_avant="$(sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p' "$avant" | sort -u)"
valeurs() { local k; for k in $cles_avant; do printf '%s=%s\n' "$k" "$(lire "$k" "$ENV_STAGING" '<absent>')"; done; }
valeurs_avant="$(valeurs)"

echo 'MON_REGLAGE_PERSO=abc123' >> "$ENV_STAGING"
CARLYS_ENV_EXAMPLES_DIR="$BANC/nulle-part" appeler config_migrer staging "$ENV_STAGING" ecrire > /dev/null || true
verifier "sans gabarit de secrets : classement refusé, rien n'est écrit" oui \
  "$(grep -q 'classement impossible' "$BANC_SORTIE" && ! ls "$ENV_STAGING".avant-config-* >/dev/null 2>&1 && echo oui || echo non)"
avant="$BANC/avant.env"; cp "$ENV_STAGING" "$avant"
cles_avant="$(sed -n 's/^\([A-Z_][A-Z0-9_]*\)=.*/\1/p' "$avant" | sort -u)"
valeurs_avant="$(valeurs)"
appeler config_migrer staging "$ENV_STAGING" essai > /dev/null || true
verifier "essai : une clé inconnue du dépôt ne montre jamais sa valeur" oui \
  "$(grep -q 'MON_REGLAGE_PERSO = (non affichée' "$BANC_SORTIE" && ! grep -q abc123 "$BANC_SORTIE" && echo oui || echo non)"
verifier "essai : rien n'est écrit" oui "$(cmp -s "$avant" "$ENV_STAGING" && echo oui || echo non)"
verifier "essai : le réglage changé à la main est montré, serveur et dépôt" oui \
  "$(grep -q 'DIFFÉRENT, gardé : LOG_LEVEL — serveur « info », dépôt « debug »' "$BANC_SORTIE" && echo oui || echo non)"
# Une clé du PREMIER fichier (commun.conf) : la liste blanche s'arrêtait là
# avant (grep -q sous pipefail, SIGPIPE), et la valeur passait pour un secret.
verifier "essai : un réglage de commun.conf aussi" oui \
  "$(grep -q 'DIFFÉRENT, gardé : SWAGGER_ENABLED — serveur « true », dépôt « false »' "$BANC_SORTIE" && echo oui || echo non)"
verifier "essai : un identifiant dans une URL n'est jamais affiché" non \
  "$(grep -q 'motdepasse' "$BANC_SORTIE" && echo oui || echo non)"
verifier "essai : aucun secret n'est affiché" non \
  "$(grep -q 'secret-du-banc' "$BANC_SORTIE" && echo oui || echo non)"

appeler config_migrer staging "$ENV_STAGING" ecrire > /dev/null || true
verifier "appliquer : chaque valeur lue est celle d'avant (rien ne change en service)" "$valeurs_avant" "$(valeurs)"
verifier "appliquer : une sauvegarde du .env, en 600" 600 "$(stat -c %a "$ENV_STAGING".avant-config-* 2>/dev/null | head -1)"
verifier "appliquer : l'état est passé dans etat.env" sha-123456789abc "$(grep '^CARLYS_TAG=' "$CARLYS_ROOT/staging/etat.env" | cut -d= -f2)"
verifier "appliquer : plus d'état dans le .env" '' "$(grep -E '^(CARLYS_TAG|CARLYS_API_REPLICAS)=' "$ENV_STAGING")"
verifier "appliquer : les réglages identiques sont partis (DOMAIN, ports…)" '' "$(grep -E '^(DOMAIN|CARLYS_API_HOST_PORT|NODE_ENV|S3_BUCKET)=' "$ENV_STAGING")"
verifier "appliquer : les secrets restent" 3 "$(grep -cE '^(POSTGRES_PASSWORD|JWT_ACCESS_SECRET|DATABASE_URL)=' "$ENV_STAGING")"
verifier "appliquer : le réglage différent reste, en attendant le dépôt" 'LOG_LEVEL=info' "$(grep '^LOG_LEVEL=' "$ENV_STAGING")"
verifier "appliquer : ce que le dépôt ne pose pas reste aussi" 1 "$(grep -c '^COACH_WORKER_URLS=' "$ENV_STAGING")"
verifier "appliquer : rejoué, il ne retire plus rien" oui \
  "$(appeler config_migrer staging "$ENV_STAGING" ecrire > /dev/null; grep -q 'rien à retirer' "$BANC_SORTIE" && echo oui || echo non)"
banc_nettoyer

echo
echo "dc — le coach sur le serveur n'existe que si le .env l'allume"

# Le défaut trouvé à la relecture du 29/09 : à zéro exemplaire, le service
# existait assez pour que `up -d` tire son image de près de 4 Go sur chaque
# serveur. Il vit donc sous le profil `ollama`, que SEUL `dc` active ; un
# COMPOSE_PROFILES du .env serait ignoré, `dc` passant déjà `--profile`.
banc_preparer
ENV_STAGING="$CARLYS_ROOT/staging/.env"
profils() {
  : > "$FAUX_JOURNAL"
  appeler dc staging "$ENV_STAGING" ps > /dev/null
  grep -q -F -- '--profile ollama' "$FAUX_JOURNAL" && echo allumé || echo éteint
}
verifier "sans CARLYS_OLLAMA_REPLICAS : profil ollama absent" éteint "$(profils)"
echo 'CARLYS_OLLAMA_REPLICAS=0' >> "$ENV_STAGING"
verifier "CARLYS_OLLAMA_REPLICAS=0 : profil ollama absent" éteint "$(profils)"
echo 'CARLYS_OLLAMA_REPLICAS=oui' >> "$ENV_STAGING"
verifier "valeur non numérique : éteint, pas d'erreur" éteint "$(profils)"
echo 'CARLYS_OLLAMA_REPLICAS=1' >> "$ENV_STAGING"
verifier "CARLYS_OLLAMA_REPLICAS=1 : profil ollama passé à compose" allumé "$(profils)"
grep -q -F -- '--profile staging' "$FAUX_JOURNAL" && garde=oui || garde=non
verifier "… sans perdre le profil de l'environnement" oui "$garde"
banc_nettoyer

echo
echo "élagage — chaque passe vide aussi ce que Docker garde sans que personne le lise"

banc_preparer
appeler prune_si_necessaire "$CARLYS_ROOT/staging/.env" > /dev/null || true
grep -q -x -F -- 'image prune -f' "$FAUX_JOURNAL" && pendantes=oui || pendantes=non
verifier "élagage : couches pendantes supprimées" oui "$pendantes"
grep -q -x -F -- 'builder prune -f --filter until=168h' "$FAUX_JOURNAL" && cache=oui || cache=non
verifier "élagage : cache de construction de plus d'une semaine supprimé" oui "$cache"
grep -q -E -- 'prune.*(-a|--all|--volumes)|volume prune' "$FAUX_JOURNAL" && large=oui || large=non
verifier "élagage : jamais -a, jamais les volumes" non "$large"
banc_nettoyer

echo
echo "env-sync — la supervision n'engendre que les secrets « engendrer-auto »"

banc_preparer
F="$CARLYS_ROOT/staging/.env"
mkdir -p "$BANC/exemples"
cat > "$BANC/exemples/staging.env.example" << 'FIN'
#carlysctl:engendrer hex32
JWT_ACCESS_SECRET=CHANGE_MOI_SECRET_JWT

#carlysctl:engendrer-auto hex32
LOG_FINGERPRINT_SECRET=CHANGE_MOI_CLE_EMPREINTES
FIN
code="$(CARLYS_ENV_EXAMPLES_DIR="$BANC/exemples" appeler envsync_appliquer staging "$F" ecrire sur)"
cle="$(grep '^LOG_FINGERPRINT_SECRET=' "$F" | cut -d= -f2)"
verifier "passe de supervision : la clé « auto » est engendrée (64 hexadécimaux)" oui \
  "$(printf '%s' "$cle" | grep -q -x -E '[0-9a-f]{64}' && echo oui || echo non)"
verifier "… jamais affichée" non "$(grep -q -F -- "$cle" "$BANC_SORTIE" && echo oui || echo non)"
verifier "… mais le secret JWT, lui, attend un humain (code 1, rien d'écrit)" "1 non" \
  "$code $(grep -q '^JWT_ACCESS_SECRET=' "$F" && echo oui || echo non)"
banc_nettoyer

echo
echo "base d'aliments CIQUAL — téléchargée, vérifiée, importée une fois par version"

banc_preparer
F="$CARLYS_ROOT/staging/.env"
# Le faux site de l'Anses : il sert $BANC/anses.zip, et note chaque téléchargement.
cat > "$BANC/bin/curl" << 'FAUX'
#!/usr/bin/env bash
echo telechargement >> "$(dirname "$FAUX_JOURNAL")/curl.journal"
# Sans archive à servir, il échoue comme un site qui ne répond pas (code 28).
while [ "$#" -gt 0 ]; do [ "$1" = -o ] && { cp "$(dirname "$FAUX_JOURNAL")/anses.zip" "$2" 2> /dev/null || exit 28; exit 0; }; shift; done
exit 1
FAUX
chmod +x "$BANC/bin/curl"
servir() { printf '%s' "$1" > "$BANC/anses.zip"; sha256sum < "$BANC/anses.zip" | cut -d' ' -f1; }
telechargements() { grep -c . "$BANC/curl.journal" 2> /dev/null || echo 0; }
export CARLYS_CIQUAL_URL=https://anses.invalid/ciqual.zip
CARLYS_CIQUAL_SHA256="$(servir 'table 2020')"
export CARLYS_CIQUAL_SHA256

code="$(appeler ciqual_importer_si_du staging "$F")"
verifier "jamais déployé → rien, ni téléchargement ni import" "0 0 0" \
  "$code $(telechargements) $(lancements ciqual-import)"
banc_deployer staging aaaaaaaaaaaa
code="$(appeler ciqual_importer_si_du staging "$F")"
verifier "premier passage → téléchargée, importée, notée" "0 1 1 $CARLYS_CIQUAL_SHA256" \
  "$code $(telechargements) $(lancements ciqual-import) $(etat staging ciqual_importee)"
verifier "… retraits acceptés, la base étant neuve" 1 "$(grep -c -- '--accepter-retraits' "$FAUX_JOURNAL")"
reculer staging import_ciqual $((25 * 3600))
code="$(appeler ciqual_importer_si_du staging "$F")"
verifier "le lendemain, version déjà en base → ni téléchargement ni import" "0 1 1" \
  "$code $(telechargements) $(lancements ciqual-import)"
verifier "… ni même un conteneur pour regarder l'image" 1 \
  "$(grep -c -F -- 'dist/cli/ciqual-import.js' "$FAUX_JOURNAL")"

CARLYS_CIQUAL_SHA256="$(servir 'table 2025')"
code="$(appeler ciqual_importer_si_du staging "$F")"
verifier "nouvelle version épinglée → tout de suite, sans attendre le lendemain" "0 2 2" \
  "$code $(telechargements) $(lancements ciqual-import)"
verifier "… mais le garde-fou des retraits joue, cette fois" 1 "$(grep -c -- '--accepter-retraits' "$FAUX_JOURNAL")"

CARLYS_CIQUAL_SHA256="$(printf 'autre' | sha256sum | cut -d' ' -f1)"
reculer staging import_ciqual $((25 * 3600))
code="$(appeler ciqual_importer_si_du staging "$F")"
verifier "empreinte différente → refusée, rien importé, alerte ouverte" "1 3 2 panne" \
  "$code $(telechargements) $(lancements ciqual-import) $(etat staging alerte_import_ciqual_etat)"
verifier "… et le fichier refusé ne reste pas sur le disque" 0 \
  "$(find "$CARLYS_ROOT/ciqual" -name '.telechargement*' | wc -l | tr -d ' ')"

CARLYS_CIQUAL_SHA256="$(servir 'table 2026')"
reculer staging import_ciqual 3700
code="$(FAUX_CLI_CODE=1 appeler ciqual_importer_si_du staging "$F")"
verifier "import en échec → 1, version pas notée comme importée" "1 oui" \
  "$code $(etat staging import_ciqual_echec)"
[ "$(etat staging ciqual_importee)" != "$CARLYS_CIQUAL_SHA256" ] && note=oui || note=non
verifier "… elle sera retentée" oui "$note"
# Le site de l'Anses ne répond plus : la production, dans la même passe,
# n'attend pas les mêmes délais une seconde fois.
CARLYS_CIQUAL_SHA256="$(servir 'table 2027')"
rm -f "$BANC/anses.zip"
avant="$(telechargements)"
code="$(appeler ciqual_importer_si_du staging "$F")"
banc_deployer production aaaaaaaaaaaa
code="$code $(appeler ciqual_importer_si_du production "$CARLYS_ROOT/production/.env")"
verifier "site injoignable → un seul essai pour toute la machine, puis pause" "1 1 1" \
  "$code $(($(telechargements) - avant))"
unset CARLYS_CIQUAL_URL CARLYS_CIQUAL_SHA256
banc_nettoyer

echo
echo "mise à l'échelle — jamais retirer un exemplaire qui sert encore une réponse"

banc_preparer
ENV_STAGING="$CARLYS_ROOT/staging/.env"
echo 'CARLYS_SCALE_DOWN_PATIENCE=1' >> "$ENV_STAGING"
decider() { appeler scale_decide staging "$ENV_STAGING" 2 1 0 '' "$1" > /dev/null; cut -d' ' -f1-3 "$BANC_SORTIE"; }
verifier "charge en baisse, rien en vol : on descend" "1 descendre charge-en-baisse" "$(decider 0)"
verifier "une réponse du coach en vol : on attend" "2 attendre requetes-en-cours" "$(decider 1)"
appeler scale_apply staging "$ENV_STAGING" 1 > /dev/null || true
grep -q -- 'up -d --no-deps --no-recreate api' "$FAUX_JOURNAL" && garde=oui || garde=non
verifier "changer le nombre ne recrée jamais les exemplaires qui restent" oui "$garde"
banc_nettoyer

echo
echo "réduire — l'exemplaire qui part est vidé par Nginx avant d'être arrêté"

# `drainage` — deux exemplaires sains ; le travail de l'api-2 (port 3101) se
# lit dans $BANC/travail-3101 et baisse d'une unité à chaque lecture.
preparer_drainage() {
  banc_preparer
  ENV_STAGING="$CARLYS_ROOT/staging/.env"
  printf 'carlys_staging-api-1|3100%s\ncarlys_staging-api-2|3101\n' "${3-}" > "$BANC/exemplaires"
  echo "$1" > "$BANC/travail-3101"
  echo "${4:-0}" > "$BANC/travail-3100"
  [ -z "${5-}" ] || echo "$5" > "$BANC/exemplaires.arretes"
  # Le faux /metrics : le format de metrics_scrape_one, code HTTP compris.
  cat > "$BANC/bin/curl" << 'FAUX'
#!/usr/bin/env bash
port="${*: -1}"; port="${port#http://127.0.0.1:}"; port="${port%%/*}"
f="$(dirname "$FAUX_JOURNAL")/travail-$port"
n="$(cat "$f")"; [ "$n" != "?" ] && [ "$n" -gt 0 ] && echo $((n - 1)) > "$f"
[ "$n" = '?' ] && { printf 'refus\n#--code--401'; exit 0; }
printf 'carlys_api_http_requests_in_flight 1\ncarlys_api_ai_work_open %s\n\n#--code--200' "$n"
FAUX
  # Le faux rechargement : il note les ports que l'amont porte À CET INSTANT.
  cat > "$BANC/bin/recharger-nginx" << 'FAUX'
#!/usr/bin/env bash
printf 'nginx %s\n' "$(grep -o '127.0.0.1:[0-9]*' "$CARLYS_NGINX_CONF_DIR"/*.conf | cut -d: -f2 | tr '\n' ' ')" >> "$FAUX_JOURNAL"
FAUX
  chmod +x "$BANC/bin/curl" "$BANC/bin/recharger-nginx"
  mkdir -p "$BANC/nginx"
  export CARLYS_NGINX_CONF_DIR="$BANC/nginx" CARLYS_NGINX_TEST=true CARLYS_NGINX_RELOAD=recharger-nginx
  export CARLYS_SCALE_DRAIN_DELAY=0 CARLYS_SCALE_DRAIN_SECONDS="${2:-30}"
}
drainage() {
  preparer_drainage "$@"
  appeler scale_apply staging "$ENV_STAGING" 1 > /dev/null || true
}

drainage 2
verifier "l'amont perd d'abord l'api-2, puis l'api-2 s'arrête" oui \
  "$([ "$(banc_rang 'nginx 3100 ')" -gt 0 ] && [ "$(banc_rang 'nginx 3100 ')" -lt "$(banc_rang 'stop carlys_staging-api-2')" ] && echo oui || echo non)"
verifier "… une fois son travail fini (lu trois fois : 2, 1, 0)" 0 "$(cat "$BANC/travail-3101")"
verifier "… jamais l'api-1, qui reste" non "$(grep -q 'stop.*api-1' "$FAUX_JOURNAL" && echo oui || echo non)"
verifier "… et etat.env porte le nouveau nombre (ADR 0017)" 1 "$(grep '^CARLYS_API_REPLICAS=' "$CARLYS_ROOT/staging/etat.env" | cut -d= -f2)"
verifier "… jamais le .env, réservé aux secrets" '' "$(grep '^CARLYS_API_REPLICAS=' "$ENV_STAGING" | cut -d= -f2)"
# Une réponse du coach finie page quittée ne tient aucune requête ouverte :
# elle compte quand même, sinon la décision descend sur elle.
echo 2 > "$BANC/travail-3100"
appeler metrics_summary staging "$ENV_STAGING" > /dev/null
verifier "le travail du coach compte dans en_vol, sans requête HTTP ouverte" en_vol=2 \
  "$(grep -o 'en_vol=[0-9]*' "$BANC_SORTIE")"
banc_nettoyer

drainage 99 0
verifier "travail qui ne finit pas à temps : personne n'est arrêté" non \
  "$(grep -q '^stop' "$FAUX_JOURNAL" && echo oui || echo non)"
verifier "… l'amont retrouve ses deux exemplaires" oui \
  "$(tail -n 1 < <(grep '^nginx' "$FAUX_JOURNAL") | grep -q '3100 3101' && echo oui || echo non)"
verifier "… et l'ancien nombre reste (rien d'écrit)" '' "$(grep -hs '^CARLYS_API_REPLICAS=' "$ENV_STAGING" "$CARLYS_ROOT/staging/etat.env" | cut -d= -f2)"
verifier "… et la commande le dit (code 1)" 1 "$(appeler scale_apply staging "$ENV_STAGING" 1)"
banc_nettoyer

drainage '?'
verifier "travail illisible (/metrics refusé) : réduction remise, personne n'est arrêté" non \
  "$(grep -q '^stop' "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

# La latence qui décide d'ajouter un exemplaire écarte les réponses du coach :
# une à trois minutes chacune, à attendre le modèle et non l'API.
banc_preparer
ENV_STAGING="$CARLYS_ROOT/staging/.env"
printf 'carlys_staging-api-1|3100\n' > "$BANC/exemplaires"
cat > "$BANC/bin/curl" << 'FAUX'
#!/usr/bin/env bash
cat << 'METRIQUES'
carlys_api_http_requests_in_flight 1
carlys_api_http_requests_total{method="GET",route="/api/v1/programs",status="200"} 10
carlys_api_http_request_duration_seconds_sum{method="GET",route="/api/v1/programs",status="200"} 1.5
carlys_api_http_request_duration_seconds_count{method="GET",route="/api/v1/programs",status="200"} 10
carlys_api_http_requests_total{method="POST",route="/api/v1/coach/conversations/:id/messages/stream",status="200"} 2
carlys_api_http_request_duration_seconds_sum{method="POST",route="/api/v1/coach/conversations/:id/messages/stream",status="200"} 240
carlys_api_http_request_duration_seconds_count{method="POST",route="/api/v1/coach/conversations/:id/messages/stream",status="200"} 2
carlys_api_http_request_duration_seconds_sum{method="POST",route="/api/v1/coach/conversations/:id/messages",status="200"} 90
carlys_api_http_request_duration_seconds_count{method="POST",route="/api/v1/coach/conversations/:id/messages",status="200"} 1
METRIQUES
printf '\n#--code--200'
FAUX
chmod +x "$BANC/bin/curl"
appeler metrics_summary staging "$ENV_STAGING" > /dev/null
verifier "latence : les réponses du coach n'y comptent pas, les requêtes si" \
  "requetes=12 latence_somme=1.500000 latence_compte=10" \
  "$(grep -o 'requetes=[0-9]* latence_somme=[0-9.]* latence_compte=[0-9]*' "$BANC_SORTIE")"
banc_nettoyer

# L'api-1 est malade : c'est elle qui part, même au plus petit numéro, et
# l'amont ne garde que la saine pendant le drainage.
drainage 0 30 '|unhealthy'
verifier "un exemplaire malade part avant un sain, quel que soit son numéro" oui \
  "$(grep -q 'stop carlys_staging-api-1' "$FAUX_JOURNAL" && ! grep -q 'stop.*api-2' "$FAUX_JOURNAL" && echo oui || echo non)"
verifier "… et l'amont du drainage ne porte que la saine" oui \
  "$(grep -q -x 'nginx 3101 ' "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

drainage 0 30 '|unhealthy' '?'
verifier "malade ET muet : il part quand même (il était déjà hors de l'amont)" oui \
  "$(grep -q 'stop carlys_staging-api-1' "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

# La BASCULE d'un déploiement (deploy.sh, étape 7) : un seul exemplaire,
# qui sert une réponse du coach (lue 2, puis 1, puis 0). La fonction tourne
# sous `set -euo pipefail`, comme dans deploy.sh, et son code est vérifié :
# elle ne doit JAMAIS faire échouer un déploiement.
bascule() {
  drainage "$1" "${2:-30}"
  if [ "$#" -ge 3 ]; then printf '%s' "$3"; else printf 'carlys_staging-api-1|3100\n'; fi > "$BANC/exemplaires"
  echo "$1" > "$BANC/travail-3100"
  CARLYS_DEPLOY_DRAIN_SECONDS="${2:-30}" banc_lancer bash -euo pipefail -c \
    '. "$0/_common.sh"; deploy_attendre_ia staging "$1"' "$BANC_SERVEUR" "$ENV_STAGING" \
    > "$BANC/code"
}
code_bascule() { cat "$BANC/code"; }
bascule 2
verifier "bascule : attend que la réponse du coach en cours finisse (code 0)" 0 "$(code_bascule)"
verifier "… jusqu'au bout" 0 "$(cat "$BANC/travail-3100")"
verifier "… et le dit" oui "$(grep -q 'la bascule attend' "$BANC_SORTIE" && echo oui || echo non)"
banc_nettoyer
bascule 99 0
verifier "bascule : une réponse qui ne finit pas à temps ne bloque pas (code 0)" 0 "$(code_bascule)"
verifier "… et le dit" oui "$(grep -q 'bascule quand même' "$BANC_SORTIE" && echo oui || echo non)"
banc_nettoyer
bascule '?'
verifier "bascule : /metrics illisible, sans attendre (code 0)" 0 "$(code_bascule)"
verifier "… et le dit" oui "$(grep -q 'bascule sans attendre' "$BANC_SORTIE" && echo oui || echo non)"
banc_nettoyer
bascule 2 'beaucoup'
verifier "bascule : délai illisible, retombé sur le défaut, sans erreur" "0 non" \
  "$(code_bascule) $(grep -q 'integer' "$BANC_SORTIE" && echo oui || echo non)"
banc_nettoyer
bascule 5 30 ''
verifier "bascule : premier déploiement, aucune API en marche, sans attendre" "0 5" \
  "$(code_bascule) $(cat "$BANC/travail-3100")"
banc_nettoyer

drainage 0 30 '' 0 carlys_staging-api-3
verifier "un conteneur arrêté en plus : rien n'est touché, ni l'amont ni personne" non \
  "$(grep -q -E '^(stop|nginx)' "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

# Le RELAIS d'un déploiement (deploy_relais) : les neufs démarrent à côté de
# l'ancien, l'amont bascule sur eux une fois sains, l'ancien finit son travail
# (lu 2, 1, 0) puis s'arrête.
# `relais <travail> <santé des neufs> [exemplaires] [conteneurs arrêtés]`
relais() {
  preparer_drainage "$1"
  if [ "$#" -ge 3 ]; then printf '%s' "$3"; else printf 'carlys_staging-api-1|3100\n'; fi > "$BANC/exemplaires"
  [ -z "${4-}" ] || printf '%s\n' "$4" > "$BANC/exemplaires.arretes"
  [ -z "${RELAIS_PLAFOND-}" ] || printf 'CARLYS_SCALE_MAX=%s\n' "$RELAIS_PLAFOND" >> "$ENV_STAGING"
  echo "$1" > "$BANC/travail-3100"
  FAUX_NEUFS_SANTE="$2" CARLYS_REPLICA_HEALTH_TRIES=3 CARLYS_REPLICA_HEALTH_DELAY=0 \
    CARLYS_DEPLOY_DRAIN_SECONDS=30 banc_lancer bash -euo pipefail -c \
    '. "$0/_common.sh"; deploy_relais staging "$1"' "$BANC_SERVEUR" "$ENV_STAGING" > "$BANC/code"
}
relais 2 healthy
verifier "relais : fait (code 0)" 0 "$(cat "$BANC/code")"
verifier "… l'amont passe sur le neuf AVANT que l'ancien ne s'arrête" oui \
  "$([ "$(banc_rang 'nginx 3111 ')" -gt 0 ] && [ "$(banc_rang 'nginx 3111 ')" -lt "$(banc_rang 'stop carlys_staging-api-1')" ] && echo oui || echo non)"
verifier "… l'ancien a fini son travail (2, 1, 0) avant de partir" 0 "$(cat "$BANC/travail-3100")"
verifier "… il ne reste que le neuf" "carlys_staging-api-2" "$(cut -d'|' -f1 "$BANC/exemplaires" | tr '\n' ' ' | sed 's/ $//')"
verifier "… né à côté, sans recréer l'ancien" oui \
  "$(grep -q -- 'up -d --no-deps --no-recreate --scale api=2 api' "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

relais 0 unhealthy
verifier "relais : neuf jamais sain — rien n'a basculé (code 1)" 1 "$(cat "$BANC/code")"
verifier "… l'ancien sert toujours, le neuf est retiré" "carlys_staging-api-1" \
  "$(cut -d'|' -f1 "$BANC/exemplaires" | tr '\n' ' ' | sed 's/ $//')"
verifier "… et l'amont n'a jamais porté le neuf" non "$(grep -q 'nginx 3111' "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

relais 0 healthy ''
verifier "relais : premier déploiement, rien en service — bascule d'avant (code 2)" 2 "$(cat "$BANC/code")"
banc_nettoyer

relais 0 healthy $'carlys_staging-api-1|3100\n' carlys_staging-api-9
verifier "relais : un conteneur arrêté en trop — bascule d'avant (code 2)" 2 "$(cat "$BANC/code")"
verifier "… sans rien faire naître" non "$(grep -q -- '--scale' "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

# Plafond à 2 (celui de la recette) : deux anciens + un neuf le dépasseraient.
RELAIS_PLAFOND=2 relais 0 healthy $'carlys_staging-api-1|3100\ncarlys_staging-api-2|3101\n'
verifier "relais : les deux générations dépasseraient le plafond — bascule d'avant (code 2)" 2 "$(cat "$BANC/code")"
verifier "… sans rien faire naître" non "$(grep -q -- '--scale' "$FAUX_JOURNAL" && echo oui || echo non)"
banc_nettoyer

FAUX_UP_ECHEC=1 relais 0 healthy
verifier "relais : le démarrage des neufs échoue — rien n'a basculé (code 1)" 1 "$(cat "$BANC/code")"
verifier "… le neuf resté « Created » est retiré (ps -a)" non \
  "$([ -s "$BANC/exemplaires.arretes" ] && echo oui || echo non)"
verifier "… l'ancien sert toujours" "carlys_staging-api-1" "$(cut -d'|' -f1 "$BANC/exemplaires" | tr '\n' ' ' | sed 's/ $//')"
banc_nettoyer

# Nginx refuse de recharger l'amont qui porte le neuf (port 3111).
preparer_amont_refuse() {
  cat > "$BANC/bin/recharger-nginx" << 'FAUX'
#!/usr/bin/env bash
ports="$(grep -o '127.0.0.1:[0-9]*' "$CARLYS_NGINX_CONF_DIR"/*.conf | cut -d: -f2 | tr '\n' ' ')"
printf 'nginx %s\n' "$ports" >> "$FAUX_JOURNAL"
case "$ports" in *3111*) exit 1 ;; esac
FAUX
}
relais_amont_refuse() {
  preparer_drainage 0
  printf 'carlys_staging-api-1|3100\n' > "$BANC/exemplaires"
  preparer_amont_refuse
  FAUX_NEUFS_SANTE=healthy CARLYS_REPLICA_HEALTH_TRIES=3 CARLYS_REPLICA_HEALTH_DELAY=0 \
    banc_lancer bash -euo pipefail -c \
    '. "$0/_common.sh"; deploy_relais staging "$1"' "$BANC_SERVEUR" "$ENV_STAGING" > "$BANC/code"
}
relais_amont_refuse
verifier "relais : amont refusé — rien n'a basculé (code 1)" 1 "$(cat "$BANC/code")"
verifier "… l'amont revient sur l'ancien AVANT que le neuf soit retiré" oui \
  "$([ "$(banc_rang 'nginx 3100 ')" -gt "$(banc_rang 'nginx 3111 ')" ] && [ "$(banc_rang 'nginx 3100 ')" -lt "$(banc_rang 'stop carlys_staging-api-2')" ] && echo oui || echo non)"
verifier "… l'ancien sert toujours, seul" "carlys_staging-api-1" "$(cut -d'|' -f1 "$BANC/exemplaires" | tr '\n' ' ' | sed 's/ $//')"
banc_nettoyer

banc_bilan
