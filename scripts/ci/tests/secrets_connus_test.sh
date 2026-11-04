#!/usr/bin/env bash
# Tests de scripts/ci/secrets_connus.py — sans TruffleHog ni réseau.
#
#   bash scripts/ci/tests/secrets_connus_test.sh
#
# Des sorties `--json` de TruffleHog écrites à la main : une découverte relue
# passe, la même valeur ailleurs échoue, et les lignes de journal ne comptent
# pas.
set -euo pipefail

ICI="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT="$ICI/../secrets_connus.py"
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
  fi
}

decouverte() { # <commit> <détecteur> <fichier ou vide> <ligne>
  local fichier=""
  [ -n "$3" ] && fichier="\"file\":\"$3\","
  printf '{"DetectorName":"%s","Redacted":"x","SourceMetadata":{"Data":{"Git":{"commit":"%s",%s"line":%s}}}}\n' \
    "$2" "$1" "$fichier" "$4"
}

cat > "$TMP/liste.txt" <<'LISTE'
# commentaire
aaaa URI tests/a.sh:3  # adresse factice
bbbb URI <message>:5
LISTE

code() { python3 "$SCRIPT" "$1" "$TMP/liste.txt" > /dev/null && echo 0 || echo $?; }

{ echo '{"level":"info","msg":"finished scanning"}'; decouverte aaaa URI tests/a.sh 3; decouverte bbbb URI "" 5; } > "$TMP/connus.jsonl"
verifier "faux positifs relus, journaux ignorés" 0 "$(code "$TMP/connus.jsonl")"

decouverte aaaa URI tests/a.sh 4 > "$TMP/autre_ligne.jsonl"
verifier "même commit, autre ligne : refusé" 1 "$(code "$TMP/autre_ligne.jsonl")"

decouverte cccc URI tests/a.sh 3 > "$TMP/autre_commit.jsonl"
verifier "même fichier, autre commit : refusé" 1 "$(code "$TMP/autre_commit.jsonl")"

decouverte aaaa AWS tests/a.sh 3 > "$TMP/autre_detecteur.jsonl"
verifier "autre détecteur : refusé" 1 "$(code "$TMP/autre_detecteur.jsonl")"

: > "$TMP/vide.jsonl"
verifier "aucune découverte" 0 "$(code "$TMP/vide.jsonl")"

printf '\n%d réussi(s), %d échec(s)\n' "$reussis" "$echecs"
[ "$echecs" -eq 0 ]
