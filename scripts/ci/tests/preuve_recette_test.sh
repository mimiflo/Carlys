#!/usr/bin/env bash
# Tests de la garde « build once » de mobile-production.yml — sans réseau ni
# GitHub.
#
#   bash scripts/ci/tests/preuve_recette_test.sh
#
# La garde vit dans le workflow (étape « Règle « build once » — ce commit a
# été construit en recette ») : l'essai en EXTRAIT le script tel quel, puis le
# joue devant un `curl` factice qui sert la liste des artefacts du dépôt comme
# l'API GitHub (filtre exact `name=`, sinon pages de 100). Aucune copie de la
# garde ici : c'est le fichier du workflow qui est jugé.
#
# POURQUOI CET ESSAI. mobile-recette garde l'APK un jour et ses symboles 30
# (audit du 25/09, ci-10 ; stockage du 28/09). La garde ne cherchait que
# l'APK : passé sa rétention, un commit bel et bien construit et éprouvé
# était refusé en production, avec un message qui parlait encore de
# « 90 jours ». Les symboles de la MÊME exécution de recette sont une preuve
# aussi bonne — ils ne naissent que si le build a réussi — et ils vivent
# 30 jours.
#
# L'essai vérifie aussi, dans mobile-recette.yml, le CONTRAT DE NOMMAGE dont
# la garde dépend : un artefact renommé là-bas sans l'être ici ferait refuser
# toutes les promotions.
set -euo pipefail

ICI="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
RACINE="$(cd -- "$ICI/../../.." && pwd -P)"
PRODUCTION="${PREUVE_RECETTE_WORKFLOW:-$RACINE/.github/workflows/mobile-production.yml}"
RECETTE="${PREUVE_RECETTE_RECETTE:-$RACINE/.github/workflows/mobile-recette.yml}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echecs=0
reussis=0
verifier() {
  local nom="$1" attendu="$2" obtenu="$3"
  if [ "$attendu" = "$obtenu" ]; then
    reussis=$((reussis + 1)); printf '  ok   %s\n' "$nom"
  else
    echecs=$((echecs + 1)); printf '  ÉCHEC %s : attendu %s, obtenu %s\n' "$nom" "$attendu" "$obtenu"
    sed 's/^/        | /' "$TMP/sortie" 2>/dev/null || true
  fi
}

# Le bloc `run: |` d'une étape, désindenté. Lecture volontairement bête du
# YAML (aucune bibliothèque à installer) : la ligne `- name: <préfixe>`, puis
# la première clé `run: |` qui suit, puis toutes les lignes plus indentées.
extraire_etape() {
  awk -v nom="$2" '
    !dans && index($0, "- name: " nom) { dans = 1; next }
    dans && !bloc && /^ *- name: / { exit }
    dans && !bloc && /^ *run: \|/ { bloc = 1; match($0, /^ */); ind = RLENGTH; next }
    bloc {
      if ($0 ~ /^ *$/) { print ""; next }
      match($0, /^ */)
      if (RLENGTH <= ind) exit
      print substr($0, ind + 3)
    }
  ' "$1"
}

SHA12=0123456789ab
extraire_etape "$PRODUCTION" 'Règle « build once »' > "$TMP/garde.sh"
# Sans ce contrôle, une extraction vide (étape renommée) rendrait 0 partout.
grep -q 'carlys-recette-apk-' "$TMP/garde.sh" && extrait=oui || extrait=non
verifier "la garde est extraite de mobile-production.yml" oui "$extrait"

# Le `curl` factice : $ARTEFACTS est un tableau JSON {name, expired,
# created_at}, du plus récent au plus ancien, comme l'API les rend.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/curl" <<'FIN'
#!/usr/bin/env bash
url="${!#}"
case "$url" in
  *'name='*)
    nom="${url##*name=}"; nom="${nom%%&*}"
    jq -c --arg n "$nom" '{artifacts: [.[] | select(.name == $n)]}' "$ARTEFACTS" ;;
  *'page='*)
    page="${url##*page=}"; page="${page%%&*}"
    jq -c --argjson p "$page" '{artifacts: .[(($p - 1) * 100):($p * 100)]}' "$ARTEFACTS" ;;
  *) echo '{"artifacts": []}' ;;
esac
FIN
chmod +x "$TMP/bin/curl"

# artefacts <nom:expiré>… — expiré vaut true ou false.
artefacts() {
  local a nom exp
  printf '[' > "$TMP/artefacts.json"
  local premier=1
  for a in "$@"; do
    nom="${a%%:*}"; exp="${a##*:}"
    [ "$premier" = 1 ] || printf ',' >> "$TMP/artefacts.json"
    premier=0
    printf '{"name":"%s","expired":%s,"created_at":"2026-09-01T10:00:00Z"}' "$nom" "$exp" >> "$TMP/artefacts.json"
  done
  printf ']\n' >> "$TMP/artefacts.json"
}

lancer() {
  local code=0
  env PATH="$TMP/bin:$PATH" ARTEFACTS="$TMP/artefacts.json" GH_TOKEN=factice SHA12="$SHA12" \
    GITHUB_API_URL=https://api.exemple GITHUB_REPOSITORY=proprietaire/depot \
    bash "$TMP/garde.sh" > "$TMP/sortie" 2>&1 || code=$?
  printf '%s' "$code"
}
dit() { grep -q -- "$1" "$TMP/sortie" && echo oui || echo non; }

echo "mobile-production.yml — garde « build once »"

artefacts "carlys-recette-apk-$SHA12:false" "carlys-recette-symboles-$SHA12:false"
verifier "APK de recette vivant → accepté" 0 "$(lancer)"

# Le cas que la rétention courte de l'APK crée : il a expiré, ses symboles
# (même exécution) vivent encore.
artefacts "carlys-recette-apk-$SHA12:true" "carlys-recette-symboles-$SHA12:false"
verifier "APK expiré, symboles de la même recette vivants → accepté" 0 "$(lancer)"
verifier "… sans avertissement « hors convention »" non "$(dit 'hors convention')"

artefacts "carlys-recette-symboles-$SHA12:false"
verifier "APK effacé de la liste, symboles vivants → accepté" 0 "$(lancer)"
verifier "… sans avertissement « hors convention »" non "$(dit 'hors convention')"

artefacts "carlys-recette-apk-$SHA12:true" "carlys-recette-symboles-$SHA12:true"
verifier "APK et symboles expirés → refusé" 1 "$(lancer)"
verifier "… et le message dit « expiré »" oui "$(dit "L'artefact de recette a expiré")"
verifier "… sans parler d'une rétention de 90 jours pour l'APK" non "$(dit '(90 jours par défaut)')"

artefacts "carlys-recette-apk-fedcba987654:false"
verifier "aucun artefact de ce commit → refusé" 1 "$(lancer)"
verifier "… « pas construit en recette »" oui "$(dit "n'a pas été construit en recette")"

# Une garde qui se prouve elle-même ne prouve rien : l'artefact que produit
# mobile-production ne compte pas.
artefacts "carlys-production-$SHA12:false"
verifier "seul l'artefact de PRODUCTION de ce commit → refusé" 1 "$(lancer)"

# Le repli par préfixe reste là pour une renommée future.
artefacts "carlys-recette-apk-v2-$SHA12:false"
verifier "nom hors convention mais de recette → accepté, avec avertissement" "0 oui" \
  "$(lancer) $(dit 'hors convention')"

echo
echo "mobile-production.yml — la CI mobile du commit promu est verte"
# « Construit en recette » ne dit pas « jugé par mobile-ci » : l'APK de
# recette naît sans attendre la CI. L'étape est extraite telle quelle et
# jouée dans un dépôt jetable dont le commit porte la vraie porte, devant un
# lecteur d'exécutions factice (VERDICT_CI_LISTER, voir verdict_ci.sh).
extraire_etape "$PRODUCTION" 'La CI mobile de ce commit est verte' > "$TMP/porte.sh"
grep -q 'verdict_ci.sh.*mobile-ci.yml' "$TMP/porte.sh" && extrait=oui || extrait=non
verifier "la porte mobile-ci est extraite de mobile-production.yml" oui "$extrait"
ligne_porte="$(grep -n -- '- name: La CI mobile de ce commit est verte' "$PRODUCTION" | cut -d: -f1 || true)"
ligne_approbation="$(grep -n '^  construire:' "$PRODUCTION" | cut -d: -f1 || true)"
[ "${ligne_porte:-0}" -gt 0 ] && [ "$ligne_porte" -lt "${ligne_approbation:-0}" ] && avant=oui || avant=non
verifier "… dans le job des gardes, AVANT l'approbation humaine" oui "$avant"

depot="$TMP/depot"
git init -q "$depot"
mkdir -p "$depot/scripts/ci"
cp "$RACINE/scripts/ci/verdict_ci.sh" "$depot/scripts/ci/"
git -C "$depot" add -A
git -C "$depot" -c user.name=t -c user.email=t@t commit -q -m promu
PROMU="$(git -C "$depot" rev-parse HEAD)"
cat > "$TMP/lister" <<'FIN'
#!/usr/bin/env bash
printf '#couvre\t0\n1\t%s\tcompleted\t%s\thttps://exemple/1\n' "$PROMU" "$CONCLUSION"
FIN
chmod +x "$TMP/lister"
porte() {
  local code=0
  (cd "$depot" && env PROMU="$PROMU" CONCLUSION="$1" VERDICT_CI_LISTER="$TMP/lister" \
    GITHUB_SHA="$PROMU" SHA40="$PROMU" RUNNER_TEMP="$TMP" GH_TOKEN=factice \
    GITHUB_REPOSITORY=proprietaire/depot GITHUB_STEP_SUMMARY='' bash "$TMP/porte.sh") \
    > "$TMP/sortie" 2>&1 || code=$?
  printf '%s' "$code"
}
verifier "mobile-ci ROUGE sur le commit promu → refusé avant l'approbation" 1 "$(porte failure)"
verifier "mobile-ci vert → la garde passe" 0 "$(porte success)"

echo
echo "mobile-recette.yml — le contrat de nommage dont la garde dépend"
# Les deux artefacts, leur nom exact et leur rétention : le contrat.
contrat() {
  awk -v nom="$1" '
    index($0, "name: " nom "${{ steps.commit.outputs.sha12 }}") { vu = 1; next }
    vu && /retention-days:/ { sub(/.*retention-days: */, ""); print; exit }
    vu && /- name: / { print "sans-retention"; exit }
  ' "$RECETTE"
}
verifier "l'APK s'appelle carlys-recette-apk-<sha12> (gardé un jour)" 1 "$(contrat carlys-recette-apk-)"
verifier "les symboles s'appellent carlys-recette-symboles-<sha12> (gardés 30 jours)" 30 "$(contrat carlys-recette-symboles-)"

printf '\n%s réussi(s), %s échec(s)\n' "$reussis" "$echecs"
[ "$echecs" -eq 0 ]
