#!/usr/bin/env bash
# Tests de scripts/ci/migrations_publiees.sh — sans réseau, dans un dépôt git
# jetable ; `gh` y est un faux qui rend le « dernier vert » demandé.
#
#   bash scripts/ci/tests/migrations_publiees_test.sh
set -euo pipefail

ICI="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT="$(cd -- "$ICI/.." && pwd -P)/migrations_publiees.sh"
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
# `lancer <argument>…` — dans le dépôt jetable ; rend le code, garde la sortie.
lancer() {
  local code=0
  (cd "$depot" && bash "$SCRIPT" "$@") > "$TMP/sortie" 2>&1 || code=$?
  echo "$code"
}
dit() { grep -q -F -- "$1" "$TMP/sortie" && echo oui || echo non; }

# Le faux `gh` : répond $VERT (vide = aucune exécution verte), note la requête.
mkdir "$TMP/bin"
cat > "$TMP/bin/gh" << 'FAUX'
#!/usr/bin/env bash
echo "$*" > "$TMP_GH/requete"
echo "${VERT-}"
FAUX
chmod +x "$TMP/bin/gh"
export PATH="$TMP/bin:$PATH" TMP_GH="$TMP" GITHUB_REPOSITORY=carlys/depot GITHUB_REF_NAME=development

# ── Un dépôt jetable : deux migrations publiées ─────────────────────────────
depot="$TMP/depot"
mig="apps/api/prisma/migrations"
git init -q "$depot"
mkdir -p "$depot/$mig/20260101000000_a" "$depot/$mig/20260102000000_b"
echo 'CREATE TABLE "A" ();' > "$depot/$mig/20260101000000_a/migration.sql"
echo 'CREATE TABLE "B" ();' > "$depot/$mig/20260102000000_b/migration.sql"
echo 'provider = "postgresql"' > "$depot/$mig/migration_lock.toml"
engager() {
  git -C "$depot" add -A
  git -C "$depot" -c user.name=t -c user.email=t@t commit -q -m "$1"
  git -C "$depot" rev-parse HEAD
}
BASE="$(engager base)"
repartir() { git -C "$depot" checkout -q -f "$BASE" && git -C "$depot" clean -q -f -d; }

verifier "rien n'a bougé → 0" 0 "$(lancer "$BASE")"

mkdir -p "$depot/$mig/20260103000000_c"
echo 'CREATE TABLE "C" ();' > "$depot/$mig/20260103000000_c/migration.sql"
echo '# verrou réécrit' >> "$depot/$mig/migration_lock.toml"
verifier "ajout d'une migration, verrou modifié → 0" 0 "$(lancer "$BASE")"
repartir

git -C "$depot" mv "$mig/20260101000000_a" "$mig/20260101999999_a"
verifier "renommage → 1" 1 "$(lancer "$BASE")"
verifier "… et le message le dit" oui "$(dit '20260101000000_a : renommée en 20260101999999_a')"
repartir

rm -r "${depot:?}/$mig/20260102000000_b"
verifier "suppression → 1" 1 "$(lancer "$BASE")"
verifier "… et le message le dit" oui "$(dit '20260102000000_b : supprimée')"
repartir

echo 'ALTER TABLE "B" ADD COLUMN "x" INT;' >> "$depot/$mig/20260102000000_b/migration.sql"
verifier "modification → 1" 1 "$(lancer "$BASE")"
verifier "… et le message le dit" oui "$(dit '20260102000000_b : modifiée')"

# ── Réécriture DÉCLARÉE : une ligne ajoutée depuis la base ──────────────────
echo '20260102000000_b contrainte violée en recette' > "$depot/$mig/REECRITES"
verifier "modification déclarée dans REECRITES → 0" 0 "$(lancer "$BASE")"
verifier "… et le message le dit" oui "$(dit '20260102000000_b : réécriture déclarée')"
echo '20260102000000_b' > "$depot/$mig/REECRITES"
verifier "déclaration sans raison → 1" 1 "$(lancer "$BASE")"
echo '20260102000000_b raison' > "$depot/$mig/REECRITES"
DECLAREE="$(engager declaration)"
echo 'ALTER TABLE "B" ADD COLUMN "y" INT;' >> "$depot/$mig/20260102000000_b/migration.sql"
verifier "déclaration déjà dans la base : ne couvre plus rien → 1" 1 "$(lancer "$DECLAREE")"
repartir

# ── En poussée : la base est le dernier commit VERT d'api-ci ────────────────
# P1 renomme une migration publiée (api-ci rouge), P2 n'a rien à voir. Le
# commit d'avant P2 est P1 : comparé à lui, le renommage a disparu.
git -C "$depot" mv "$mig/20260101000000_a" "$mig/20260101999999_a"
P1="$(engager renommage)"
echo x > "$depot/sans-rapport.txt"
engager sans-rapport > /dev/null
verifier "P1 réécrit, P2 sans rapport, dernier vert avant P1 → 1" 1 "$(VERT="$BASE" lancer --poussee "$P1")"
verifier "… et le message nomme le renommage de P1" oui "$(dit '20260101000000_a : renommée en 20260101999999_a')"
verifier "… la requête ne veut que les poussées vertes de la branche" oui \
  "$(grep -q -F 'branch=development&event=push&status=success' "$TMP/requete" 2> /dev/null && echo oui || echo non)"
verifier "aucune exécution verte : repli sur le commit d'avant la poussée" 0 "$(VERT='' lancer --poussee "$P1")"
verifier "première poussée d'une branche → 0" 0 \
  "$(VERT='' lancer --poussee 0000000000000000000000000000000000000000)"
repartir

verifier "base introuvable → 1" 1 "$(lancer 0123456789abcdef0123456789abcdef01234567)"
verifier "… et le message le dit" oui "$(dit 'introuvable')"

printf '\n%s réussi(s), %s échec(s)\n' "$reussis" "$echecs"
[ "$echecs" -eq 0 ]
