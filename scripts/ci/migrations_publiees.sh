#!/usr/bin/env bash
# Une migration Prisma PUBLIÉE ne se renomme, ne se supprime ni ne se
# modifie : on en écrit une nouvelle. Règle, incident du 19/09 et exception :
# docs/database/migrations.md.
#
#   scripts/ci/migrations_publiees.sh <base>
#   scripts/ci/migrations_publiees.sh --poussee <commit d'avant la poussée>
#
# Compare chaque apps/api/prisma/migrations/*/migration.sql de <base> (un
# commit déjà poussé) à l'arbre de travail. Les AJOUTS passent ;
# migration_lock.toml n'est pas regardé. Une réécriture n'est admise que
# DÉCLARÉE : une ligne « <dossier> <raison> » AJOUTÉE à REECRITES depuis
# <base> — une déclaration déjà publiée ne couvre plus rien. Sort en 1 sur
# une réécriture non déclarée, ou si <base> est introuvable : sans elle,
# rien ne prouve que l'historique est intact.
#
# --poussee (api-ci) : la base est le dernier commit dont api-ci a été VERT
# en poussée sur cette branche (`gh`, droit `actions: read`), le commit
# d'avant la poussée à défaut. Le commit d'avant ne suffit pas : une
# réécriture rouge suivie d'une poussée sans rapport passerait au vert — et
# ses images partiraient en recette. Un vert devenu introuvable (poussée
# forcée, puis ménage côté GitHub) cède la place au vert d'avant lui, parmi
# les vingt derniers ; le commit d'avant la poussée ne sert qu'en dernier.
set -euo pipefail

usage="usage : migrations_publiees.sh <base> | --poussee <commit d'avant>"
cd "$(git rev-parse --show-toplevel)"

# `joignable <commit>` — 0 : présent, ou rapatrié (clone superficiel en CI) ;
# 1 : DISPARU du dépôt distant (« not our ref ») ; 2 : autre échec (réseau,
# GitHub en panne). Seul un commit disparu cède la place au vert d'avant :
# sur une panne passagère, la garde s'arrête, elle ne baisse pas d'un cran.
joignable() {
  local erreur
  git cat-file -e "$1^{commit}" 2> /dev/null && return 0
  # LC_ALL=C : git traduit ses propres messages ; seul l'anglais se reconnaît.
  erreur="$(LC_ALL=C git fetch -q --no-tags --depth=1 origin "$1" 2>&1)" && return 0
  grep -q -i -E "not our ref|unadvertised object|couldn't find remote ref|no such remote ref" \
    <<< "$erreur" && return 1
  printf '%s\n' "$erreur" >&2
  return 2
}

if [ "${1-}" = --poussee ]; then
  avant="${2:?$usage}"
  # Capturé d'abord : une panne de `gh` arrête la garde, elle ne la replie
  # pas en silence sur le commit d'avant.
  verts="$(gh api "repos/$GITHUB_REPOSITORY/actions/workflows/api-ci.yml/runs?branch=$GITHUB_REF_NAME&event=push&status=success&per_page=20" \
    --jq '.workflow_runs[].head_sha')"
  base=''
  while read -r vert; do
    [ -n "$vert" ] || continue
    code=0
    joignable "$vert" || code=$?
    if [ "$code" -eq 0 ]; then
      base="$vert"
      break
    fi
    if [ "$code" -eq 2 ]; then
      echo "✗ Dernier vert ${vert:0:12} injoignable (réseau ?) : refus par prudence." >&2
      exit 1
    fi
    echo "  ~ dernier vert ${vert:0:12} introuvable (historique réécrit ?) : le précédent."
  done <<< "$verts"
  if [ -z "$base" ] && [ -n "$verts" ]; then
    echo "::warning::Aucun des derniers verts d'api-ci n'est joignable : la garde des migrations compare au seul commit d'avant la poussée."
  fi
  base="${base:-$avant}"
else
  base="${1:?$usage}"
fi
if [ "$base" = 0000000000000000000000000000000000000000 ]; then
  echo "Première poussée de la branche : aucune migration n'y était publiée."
  exit 0
fi

joignable "$base" || true
court="$(git rev-parse --verify --quiet --short=12 "$base^{commit}")" || {
  echo "✗ Commit « $base » introuvable dans l'historique : impossible de prouver" >&2
  echo "  que les migrations déjà publiées sont intactes. Refus par prudence." >&2
  exit 1
}

mig=apps/api/prisma/migrations
declarees="$(comm -13 <(git show "$base:$mig/REECRITES" 2> /dev/null | sort) \
  <(sort "$mig/REECRITES" 2> /dev/null) | awk 'NF >= 2 { print $1 }')"
fautes="$(git diff --find-renames --name-status --diff-filter=DMR "$base" -- "$mig/*/migration.sql")"

dossier() { basename "$(dirname "$1")"; }
rapport=''
while IFS=$'\t' read -r statut chemin nouveau; do
  [ -n "$statut" ] || continue
  d="$(dossier "$chemin")"
  if grep -q -x -F -- "$d" <<< "$declarees"; then
    echo "  ~ $d : réécriture déclarée dans $mig/REECRITES"
    continue
  fi
  case "$statut" in
    D) rapport+="  - $d : supprimée"$'\n' ;;
    M) rapport+="  - $d : modifiée"$'\n' ;;
    R*) rapport+="  - $d : renommée en $(dossier "$nouveau")"$'\n' ;;
  esac
done <<< "$fautes"

if [ -z "$rapport" ]; then
  echo "✓ Migrations publiées intactes depuis $court."
  exit 0
fi
{
  echo "✗ Des migrations Prisma déjà publiées (dans $court) ont été réécrites :"
  printf '%s' "$rapport"
  echo
  echo "Une migration publiée ne se renomme, ne se supprime ni ne se modifie :"
  echo "on en écrit une NOUVELLE. Renommée, un serveur qui l'a déjà appliquée la"
  echo "rejoue, échoue, puis refuse toute migration suivante ; modifiée, elle passe"
  echo "sans un mot et les bases déjà migrées divergent des neuves."
  echo "Remettre chaque dossier tel qu'il est dans la base (et retirer la copie"
  echo "renommée) :  git checkout $court -- $mig/<dossier>"
  echo "Réécriture NÉCESSAIRE (migration en échec sur un serveur) ou serveur déjà"
  echo "tombé : docs/database/migrations.md."
} >&2
exit 1
