#!/usr/bin/env bash
# Tests de scripts/ci/verdict_ci.sh — sans réseau ni GitHub.
#
#   bash scripts/ci/tests/verdict_ci_test.sh
#
# Un dépôt git jetable porte l'historique, et VERDICT_CI_LISTER remplace
# l'API GitHub par un lecteur de fichiers : un fichier par workflow, une ligne
# par exécution (id, sha, status, conclusion, url), comme l'API les rend —
# fenêtre des plus récentes comprise, et question exacte par sha.
set -euo pipefail

ICI="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT="${VERDICT_CI_SCRIPT:-$ICI/../verdict_ci.sh}"
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
    sed 's/^/        | /' "$TMP/sortie" || true
  fi
}

# ── Un historique : A (api) → B (docs seules) → C (api), il y a dix jours ────
depot="$TMP/depot"
git init -q "$depot"
DIX_JOURS="$(($(date +%s) - 10 * 86400))"
for m in A B C; do
  GIT_COMMITTER_DATE="@$DIX_JOURS +0000" GIT_AUTHOR_DATE="@$DIX_JOURS +0000" \
    git -C "$depot" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "$m"
done
C="$(git -C "$depot" rev-parse HEAD)"
B="$(git -C "$depot" rev-parse HEAD~1)"
A="$(git -C "$depot" rev-parse HEAD~2)"

# ── Puis de vrais fichiers : X0 → X1 (API) → X2 (docs) → X3 (docs) ──────────
# X1 et X2 sont poussés ENSEMBLE : api-ci ne tourne que sur la tête, X2. Le
# workflow du dépôt jetable surveille apps/api/** en poussée — et docs/** en
# pull request seulement, pour prouver que seuls les chemins de `push` comptent.
mkdir -p "$depot/.github/workflows" "$depot/apps/api" "$depot/docs"
cat > "$depot/.github/workflows/api-ci.yml" <<'FIN'
on:
  pull_request:
    paths:
      - 'docs/**'
  push:
    branches: [development]
    # Un commentaire, comme dans les vrais workflows.
    paths:
      - 'apps/api/**'
      - '.github/workflows/api-ci.yml'
jobs: {}
FIN
engager() {
  printf '%s\n' "$2" >> "$depot/$1"
  git -C "$depot" add -A
  GIT_COMMITTER_DATE="@$DIX_JOURS +0000" GIT_AUTHOR_DATE="@$DIX_JOURS +0000" \
    git -C "$depot" -c user.name=t -c user.email=t@t commit -q -m "$1"
  git -C "$depot" rev-parse HEAD
}
engager docs/d.md d0 > /dev/null
X0="$(engager apps/api/a.ts a0)"
X1="$(engager apps/api/a.ts a1)"
X2="$(engager docs/d.md d1)"
X3="$(engager docs/d.md d2)"

# Le lecteur : $EXECUTIONS/<workflow> ; un fichier <workflow>.suite remplace
# le premier après N lectures (N dans <workflow>.apres) — une exécution qui se
# termine pendant l'attente.
#
# Comme l'API : sans sha, la FENÊTRE — toutes les exécutions et « #couvre 0 »
# (liste complète), ou, si <workflow>.fenetre contient « N date », les N plus
# récentes et « #couvre date » (date epoch de la plus vieille listée). Avec un
# sha, les exécutions de ce sha seulement, comptées dans <workflow>.exactes.
cat > "$TMP/lister" <<'FIN'
#!/usr/bin/env bash
f="$EXECUTIONS/$1"
if [ -f "$f.suite" ]; then
  n="$(cat "$f.lu" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" > "$f.lu"
  if [ "$n" -gt "$(cat "$f.apres")" ]; then f="$f.suite"; fi
fi
[ -f "$f" ] || exit 0
if [ -n "${2-}" ]; then
  echo $(($(cat "$EXECUTIONS/$1.exactes" 2>/dev/null || echo 0) + 1)) > "$EXECUTIONS/$1.exactes"
  printf '#couvre\t0\n'
  awk -F'\t' -v s="$2" '$2 == s' "$f"
elif [ -f "$EXECUTIONS/$1.fenetre" ]; then
  read -r n couvre < "$EXECUTIONS/$1.fenetre"
  printf '#couvre\t%s\n' "$couvre"
  sort -t$'\t' -k1,1nr "$f" | head -n "$n"
else
  printf '#couvre\t0\n'
  cat "$f"
fi
exit 0
FIN
chmod +x "$TMP/lister"

lancer() {
  # lancer <sha> <workflow…> — rend le code de sortie du script.
  local code=0
  (cd "$depot" && EXECUTIONS="$TMP/exec" VERDICT_CI_LISTER="$TMP/lister" \
    VERDICT_CI_PAUSE="${PAUSE:-0}" VERDICT_CI_DELAI="${DELAI:-30}" \
    GITHUB_STEP_SUMMARY='' bash "$SCRIPT" "$@") > "$TMP/sortie" 2>&1 || code=$?
  printf '%s' "$code"
}
executions() {
  # executions <workflow> <lignes…> ; chaque ligne : "id sha status conclusion"
  local wf="$1"; shift
  rm -rf "$TMP/exec"; mkdir -p "$TMP/exec"
  : > "$TMP/exec/$wf"
  local l
  for l in "$@"; do
    # shellcheck disable=SC2086 # découpage voulu des quatre champs
    set -- $l
    printf '%s\t%s\t%s\t%s\thttps://exemple/%s\n' "$1" "$2" "$3" "${4:--}" "$1" >> "$TMP/exec/$wf"
  done
}

echo "verdict_ci.sh"

executions api-ci.yml "10 $C completed success"
verifier "exécution verte sur le commit lui-même → 0" 0 "$(lancer "$C" api-ci.yml)"

executions api-ci.yml "10 $C completed failure"
verifier "exécution rouge sur le commit lui-même → 1" 1 "$(lancer "$C" api-ci.yml)"

# Le trou des filtres `paths` : B ne déclenche pas api-ci, mais embarque le
# code d'API de A, qui était rouge.
executions api-ci.yml "10 $A completed failure"
verifier "pas d'exécution sur B, ancêtre A rouge → 1" 1 "$(lancer "$B" api-ci.yml)"

executions api-ci.yml "10 $A completed success"
verifier "pas d'exécution sur B, ancêtre A vert → 0" 0 "$(lancer "$B" api-ci.yml)"

# C'est l'ancêtre le PLUS PROCHE qui juge : C a réparé ce que A avait cassé.
executions api-ci.yml "10 $A completed failure" "11 $C completed success"
verifier "ancêtre lointain rouge, commit vert → 0" 0 "$(lancer "$C" api-ci.yml)"

executions api-ci.yml
verifier "aucune exécution nulle part → 0 (sans objet)" 0 "$(lancer "$C" api-ci.yml)"

executions api-ci.yml "10 $C completed cancelled"
verifier "exécution annulée → 1 (rien de prouvé)" 1 "$(lancer "$C" api-ci.yml)"

executions api-ci.yml "10 $C completed skipped"
verifier "exécution sautée → 0" 0 "$(lancer "$C" api-ci.yml)"

# Deux exécutions du même commit : la plus récente fait foi.
executions api-ci.yml "12 $C completed success" "10 $C completed failure"
verifier "rouge puis vert sur le même commit → 0" 0 "$(lancer "$C" api-ci.yml)"
executions api-ci.yml "10 $C completed success" "12 $C completed failure"
verifier "vert puis rouge sur le même commit → 1" 1 "$(lancer "$C" api-ci.yml)"

# Une exécution en cours se termine pendant l'attente.
executions api-ci.yml "10 $C in_progress"
printf '10\t%s\tcompleted\tsuccess\thttps://exemple/10\n' "$C" > "$TMP/exec/api-ci.yml.suite"
echo 1 > "$TMP/exec/api-ci.yml.apres"
verifier "en cours puis vert → 0 après attente" 0 "$(lancer "$C" api-ci.yml)"
grep -q 'En attente de : api-ci.yml' "$TMP/sortie" && a_attendu=oui || a_attendu=non
verifier "… et le script a bien attendu" oui "$a_attendu"

executions api-ci.yml "10 $C queued"
verifier "toujours en cours au-delà du délai → 2" 2 "$(DELAI=0 lancer "$C" api-ci.yml)"

# Plusieurs workflows : un seul rouge suffit.
executions api-ci.yml "10 $C completed success"
printf '11\t%s\tcompleted\tfailure\thttps://exemple/11\n' "$A" > "$TMP/exec/images-ci.yml"
verifier "api-ci vert, images-ci rouge sur l'ancêtre → 1" 1 "$(lancer "$C" api-ci.yml images-ci.yml admin-ci.yml)"
grep -q 'images-ci.yml : failure' "$TMP/sortie" && nomme=oui || nomme=non
verifier "… et le message nomme le workflow rouge" oui "$nomme"

verifier "sans workflow → 3 (usage)" 3 "$(lancer "$C")"

# ── La fenêtre des 100 dernières exécutions ─────────────────────────────────
# Le rattrapage d'un commit ROUGE d'il y a dix jours : son exécution est
# sortie de la fenêtre (100 exécutions plus récentes, d'un autre commit). La
# première rédaction concluait « sans objet », puis « CI verte ».
AUTRE=0123456789abcdef0123456789abcdef01234567
AVANT_HIER="$(($(date +%s) - 2 * 86400))"
fenetre() { printf '%s %s\n' "$2" "$3" > "$TMP/exec/$1.fenetre"; }
lignes_autres=()
for i in $(seq 200 299); do lignes_autres+=("$i $AUTRE completed success"); done

executions api-ci.yml "10 $C completed failure" "${lignes_autres[@]}"
fenetre api-ci.yml 100 "$AVANT_HIER"
verifier "commit rouge sorti de la fenêtre → 1 (demandé par son sha)" 1 "$(lancer "$C" api-ci.yml)"

executions api-ci.yml "10 $A completed failure" "${lignes_autres[@]}"
fenetre api-ci.yml 100 "$AVANT_HIER"
verifier "hors fenêtre, ancêtre A rouge sous B sans exécution → 1" 1 "$(lancer "$B" api-ci.yml)"

executions api-ci.yml "10 $C completed success" "${lignes_autres[@]}"
fenetre api-ci.yml 100 "$AVANT_HIER"
verifier "commit vert sorti de la fenêtre → 0" 0 "$(lancer "$C" api-ci.yml)"

# Rien trouvé, ni dans la fenêtre ni par sha, au-delà du plafond de questions.
executions api-ci.yml "${lignes_autres[@]}"
fenetre api-ci.yml 100 "$AVANT_HIER"
verifier "hors fenêtre, rien trouvé en 2 questions → 2 (hors de portée), pas « sans objet »" 2 \
  "$(VERDICT_CI_REQUETES_MAX=2 lancer "$C" api-ci.yml)"
grep -q 'historique hors de portée' "$TMP/sortie" && dit=oui || dit=non
verifier "… et le message le dit" oui "$dit"
grep -q 'CI verte' "$TMP/sortie" && verte=oui || verte=non
verifier "… sans jamais annoncer « CI verte »" non "$verte"

# La fenêtre REMONTE avant ces commits : l'absence y est une preuve, et
# aucune question exacte n'est posée.
executions api-ci.yml "${lignes_autres[@]}"
fenetre api-ci.yml 100 "$(($(date +%s) - 30 * 86400))"
verifier "fenêtre plus ancienne que les commits, rien trouvé → 0 (sans objet)" 0 "$(lancer "$C" api-ci.yml)"
verifier "… sans aucune question exacte" 0 "$(cat "$TMP/exec/api-ci.yml.exactes" 2>/dev/null || echo 0)"

# Un verdict acquis n'est pas redemandé pendant qu'un autre workflow tourne.
executions api-ci.yml "10 $C completed success" "${lignes_autres[@]}"
fenetre api-ci.yml 100 "$AVANT_HIER"
printf '11\t%s\tin_progress\t-\thttps://exemple/11\n' "$C" > "$TMP/exec/images-ci.yml"
printf '11\t%s\tcompleted\tsuccess\thttps://exemple/11\n' "$C" > "$TMP/exec/images-ci.yml.suite"
echo 3 > "$TMP/exec/images-ci.yml.apres"
verifier "hors fenêtre et en attente d'un autre → 0" 0 "$(lancer "$C" api-ci.yml images-ci.yml)"
verifier "… la question exacte n'est posée qu'une fois" 1 "$(cat "$TMP/exec/api-ci.yml.exactes" 2>/dev/null || echo 0)"

# La marge d'horloge. La fenêtre remonte à 12 h AVANT le commit : sans marge,
# elle semblerait assez longue, l'absence de C y passerait pour une preuve, et
# C — rouge, sorti de la fenêtre — finirait « sans objet ». Une horloge de
# poste en avance d'un jour ne doit pas suffire à ce qu'on y croie.
executions api-ci.yml "10 $C completed failure" "${lignes_autres[@]}"
fenetre api-ci.yml 100 "$((DIX_JOURS - 12 * 3600))"
verifier "fenêtre à 12 h du commit : la marge d'horloge fait poser la question exacte → 1" 1 \
  "$(lancer "$C" api-ci.yml)"

# ── Une poussée groupée n'a qu'une exécution, sur sa tête ───────────────────
# X1 n'a pas d'exécution à lui ; son ancêtre X0 est vert, sa tête X2 rouge.
# Le verdict de X0 ne dit rien de X1, qui a changé l'API depuis. La première
# rédaction le prenait pourtant, et publiait X1 au rattrapage.
executions api-ci.yml "20 $X0 completed success" "21 $X2 completed failure"
verifier "commit du milieu d'une poussée : pas de verdict propre → 2, jamais « vert »" 2 \
  "$(lancer "$X1" api-ci.yml)"
grep -q "jamais jugé" "$TMP/sortie" && dit=oui || dit=non
verifier "… et le message le dit" oui "$dit"
verifier "la tête de cette poussée garde son verdict → 1" 1 "$(lancer "$X2" api-ci.yml)"

# Les docs seules après un commit jugé : rien de ce qu'api-ci surveille en
# POUSSÉE n'a bougé (docs/** ne compte qu'en pull request), le verdict vaut.
executions api-ci.yml "22 $X2 completed success"
verifier "docs seules depuis le dernier commit jugé → 0 (son verdict vaut)" 0 "$(lancer "$X3" api-ci.yml)"
executions api-ci.yml "22 $X2 completed failure"
verifier "docs seules depuis un commit jugé rouge → 1" 1 "$(lancer "$X3" api-ci.yml)"

printf '\n%s réussi(s), %s échec(s)\n' "$reussis" "$echecs"
[ "$echecs" -eq 0 ]
