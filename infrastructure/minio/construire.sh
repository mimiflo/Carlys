#!/bin/sh
# Construit minio ou mc DEPUIS SES SOURCES officielles — et identifie le résultat.
#
#   sh infrastructure/minio/construire.sh minio <dossier-de-sortie>
#   sh infrastructure/minio/construire.sh mc    <dossier-de-sortie>
#   sh infrastructure/minio/construire.sh etiquettes
#   sh infrastructure/minio/construire.sh verifier-compose <compose.yml>
#
# POURQUOI CONSTRUIRE. MinIO a cessé de distribuer son édition communautaire
# (images et binaires : dl.min.io rend 410). Les dépôts minio/minio et minio/mc
# ont d'abord DISPARU de Docker Hub (api-ci rouge le 12 septembre 2026), puis
# quay.io, où l'on s'était replié, a cessé de les servir à son tour (api-ci
# rouge le 24 septembre 2026 : « unauthorized: access to the requested
# resource is not authorized », en une seconde, sur des commits qui ne
# touchaient pas l'API). Deux registres tiers, deux pannes : on ne dépend plus
# d'aucun. Les SOURCES, elles, restent publiques — github.com/minio/minio et
# github.com/minio/mc, licence GNU AGPLv3.
#
# UN SEUL SCRIPT POUR TOUS LES CONSOMMATEURS : le Dockerfile de ce dossier
# (développement et serveur), api-ci (binaires nus) et un poste de travail. Les
# trois recettes écrites à part auraient divergé à la première montée de
# version ; celle-ci ne le peut pas.
#
# CE QUE LA CONSTRUCTION GARANTIT, dans l'ordre :
#   1. le Go utilisé est EXACTEMENT celui de versions.env (GOTOOLCHAIN=local :
#      jamais de téléchargement silencieux d'une autre chaîne) ;
#   2. le tag cloné désigne bien le commit écrit dans versions.env — un tag
#      déplacé en amont fait échouer, il ne fait pas construire autre chose ;
#   3. le binaire est statique (CGO_ENABLED=0) et sans chemin local
#      (-trimpath), avec les mêmes options et la même identité de version que
#      les versions officielles (buildscripts/gen-ldflags.go de l'amont, tag
#      de build `kqueue`) ;
#   4. `<binaire> --version` annonce bien ce tag et ce commit.
#
# Et à côté du binaire : licences/<composant>/ (LICENSE, CREDITS et SOURCE —
# dépôt, tag, commit, Go), que le Dockerfile recopie dans l'image. L'AGPLv3
# veut que la source correspondante reste désignable : elle l'est, au commit.
#
# POSIX sh volontairement : l'étage de construction du Dockerfile est une
# Debian, la CI une Ubuntu (dash toutes deux), un poste peut être un Mac. Ni
# bash, ni make — seulement git, go et les outils POSIX.
set -eu

ici=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

die() {
  printf 'construire.sh : %s\n' "$1" >&2
  shift
  for ligne in "$@"; do printf '  %s\n' "$ligne" >&2; done
  exit 1
}

usage() {
  sed -n '4,7p' "$ici/construire.sh" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

[ -f "$ici/versions.env" ] || die "versions.env introuvable à côté du script ($ici)."
# shellcheck source=infrastructure/minio/versions.env
. "$ici/versions.env"
for cle in CARLYS_MINIO_RELEASE CARLYS_MINIO_COMMIT CARLYS_MC_RELEASE CARLYS_MC_COMMIT CARLYS_MINIO_GO_VERSION; do
  eval "valeur=\${$cle:-}"
  [ -n "$valeur" ] || die "$cle est absente ou vide dans versions.env."
done

# ── Étiquettes des images publiées ────────────────────────────────────────
# `<version de l'amont>-<empreinte de la recette>`. L'empreinte couvre les
# trois fichiers qui décident du contenu de l'image — ce script, versions.env
# et le Dockerfile —, ni plus (un README modifié ne republie rien) ni moins (un
# changement d'image de base, de Go ou d'option de build change l'étiquette).
#
# D'où une étiquette IMMUABLE : même recette, même étiquette ; recette changée,
# étiquette nouvelle. images-publish ne republie donc jamais par-dessus une
# étiquette existante, et une poussée sur la branche de travail ne peut pas
# modifier en douce l'image que la production tire.
#
# `tr -d '\r'` : un poste Windows qui extrait les fichiers en CRLF doit
# calculer la même empreinte que la CI.
empreinte_recette() {
  if command -v sha256sum >/dev/null 2>&1; then
    cat "$ici/Dockerfile" "$ici/versions.env" "$ici/construire.sh" | tr -d '\r' | sha256sum | cut -c1-12
  else
    cat "$ici/Dockerfile" "$ici/versions.env" "$ici/construire.sh" | tr -d '\r' | shasum -a 256 | cut -c1-12
  fi
}

etiquette_minio() { printf '%s-%s' "$CARLYS_MINIO_RELEASE" "$(empreinte_recette)"; }
etiquette_mc() { printf '%s-%s' "$CARLYS_MC_RELEASE" "$(empreinte_recette)"; }

# ── Le serveur tire-t-il bien ce que la recette produit ? ────────────────
# infrastructure/server/compose.yml porte les deux étiquettes en valeur par
# défaut de CARLYS_MINIO_IMAGE et CARLYS_MC_IMAGE : c'est la seule recopie, et
# elle est vérifiée ici plutôt que crue.
verifier_compose() {
  fichier=$1
  [ -f "$fichier" ] || die "fichier compose introuvable : $fichier"
  manque=0
  for attendu in "carlys-minio:$(etiquette_minio)" "carlys-mc:$(etiquette_mc)"; do
    if grep -qF "/$attendu}" "$fichier"; then
      printf 'ok  %s\n' "$attendu"
    else
      printf 'ÉCART  %s ne référence pas %s\n' "$fichier" "$attendu" >&2
      manque=1
    fi
  done
  [ "$manque" -eq 0 ] || die "la recette de infrastructure/minio/ a changé sans que $fichier suive." \
    "Remplacer, dans les valeurs par défaut de CARLYS_MINIO_IMAGE et CARLYS_MC_IMAGE," \
    "les étiquettes par celles-ci :" \
    "  \${CARLYS_REGISTRY}/carlys-minio:$(etiquette_minio)" \
    "  \${CARLYS_REGISTRY}/carlys-mc:$(etiquette_mc)" \
    "(procédure complète : infrastructure/minio/README.md, « Monter de version »)."
}

# ── Construction ──────────────────────────────────────────────────────────
construire() {
  composant=$1
  sortie=$2
  case "$composant" in
    minio)
      depot=https://github.com/minio/minio
      tag=$CARLYS_MINIO_RELEASE
      commit=$CARLYS_MINIO_COMMIT
      prefixe=MINIO
      ;;
    mc)
      depot=https://github.com/minio/mc
      tag=$CARLYS_MC_RELEASE
      commit=$CARLYS_MC_COMMIT
      prefixe=MC
      ;;
    *) usage ;;
  esac

  command -v git >/dev/null 2>&1 || die "git est requis pour cloner $depot."
  command -v go >/dev/null 2>&1 || die "go $CARLYS_MINIO_GO_VERSION est requis pour construire $composant."

  # 1. Le bon Go, et lui seul. Sans GOTOOLCHAIN=local, un go.mod qui exigerait
  #    une chaîne plus récente la ferait télécharger sans un mot : le binaire
  #    ne serait plus construit avec le Go que ce dépôt déclare.
  GOTOOLCHAIN=local
  export GOTOOLCHAIN
  go_actuel=$(go env GOVERSION)
  [ "$go_actuel" = "go$CARLYS_MINIO_GO_VERSION" ] || die \
    "Go $CARLYS_MINIO_GO_VERSION attendu (versions.env), $go_actuel trouvé." \
    "En CI : la version passée à actions/setup-go vient de versions.env." \
    "Dans le Dockerfile : aligner le FROM golang sur CARLYS_MINIO_GO_VERSION." \
    "Sur un poste : GOTOOLCHAIN=go$CARLYS_MINIO_GO_VERSION go env GOROOT télécharge la chaîne," \
    "puis mettre <ce GOROOT>/bin en tête du PATH."

  # Le format que gen-ldflags.go attend : RELEASE.2025-09-07T16-13-09Z donne
  # 2025-09-07T16:13:09Z — la transformation même du Makefile de l'amont.
  version=$(printf '%s\n' "$tag" | sed -n 's/^RELEASE\.\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)T\([0-9]\{2\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)Z$/\1T\2:\3:\4Z/p')
  [ -n "$version" ] || die "tag « $tag » : la forme RELEASE.AAAA-MM-JJTHH-MM-SSZ est attendue."

  mkdir -p "$sortie"
  sortie=$(CDPATH='' cd -- "$sortie" && pwd)
  travail=$(mktemp -d)
  # shellcheck disable=SC2064 # $travail est figé ICI, c'est voulu
  trap "rm -rf '$travail'" EXIT
  # Une interruption doit ARRÊTER le script (le piège EXIT nettoie ensuite) :
  # piéger INT pour nettoyer sans sortir le laisserait continuer.
  trap 'exit 130' INT TERM
  debut=$(date +%s)

  # 2. Le tag, puis la preuve qu'il désigne le commit attendu.
  printf '── %s %s : clone de %s\n' "$composant" "$tag" "$depot"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$tag" "$depot" "$travail/src"
  obtenu=$(git -C "$travail/src" rev-parse HEAD)
  [ "$obtenu" = "$commit" ] || die \
    "le tag $tag de $depot désigne le commit $obtenu," \
    "versions.env attend $commit. Tag DÉPLACÉ en amont, ou versions.env faux :" \
    "ne rien construire tant que l'écart n'est pas compris." \
    "Vérification : git ls-remote $depot 'refs/tags/$tag^{}'"
  printf '   commit vérifié : %s\n' "$obtenu"

  # 3. Les options officielles. `MINIO_RELEASE=RELEASE` (ou MC_RELEASE) est
  #    le préfixe que gen-ldflags.go attend pour produire une ReleaseTag
  #    « RELEASE.… » — sans lui, le binaire se dirait DEVELOPMENT.
  printf '   construction avec %s (CGO_ENABLED=0, -trimpath)\n' "$go_actuel"
  (
    cd "$travail/src"
    ldflags=$(env "${prefixe}_RELEASE=RELEASE" go run buildscripts/gen-ldflags.go "$version")
    CGO_ENABLED=0 go build -tags kqueue -trimpath -ldflags "$ldflags" -o "$sortie/$composant" .
  )

  # 4. Le binaire dit-il ce qu'on croit avoir construit ?
  annonce=$("$sortie/$composant" --version 2>&1 | sed -n 1p)
  case "$annonce" in
    *"$tag"*"$commit"*) ;;
    *) die "« $composant --version » n'annonce pas $tag / $commit :" "$annonce" ;;
  esac

  mkdir -p "$sortie/licences/$composant"
  cp "$travail/src/LICENSE" "$travail/src/CREDITS" "$sortie/licences/$composant/"
  {
    printf 'Composant : %s (GNU AGPLv3)\n' "$composant"
    printf 'Dépôt     : %s\n' "$depot"
    printf 'Tag       : %s\n' "$tag"
    printf 'Commit    : %s\n' "$commit"
    printf 'Go        : %s\n' "$go_actuel"
    printf 'Construit sans modification, par infrastructure/minio/construire.sh (Carlys).\n'
  } > "$sortie/licences/$composant/SOURCE"

  printf '   %s — construit en %s s : %s\n' "$annonce" "$(($(date +%s) - debut))" "$sortie/$composant"
}

case "${1:-}" in
  minio | mc)
    [ $# -eq 2 ] || usage
    construire "$1" "$2"
    ;;
  etiquettes)
    [ $# -eq 1 ] || usage
    printf 'minio=%s\n' "$(etiquette_minio)"
    printf 'mc=%s\n' "$(etiquette_mc)"
    ;;
  verifier-compose)
    [ $# -eq 2 ] || usage
    verifier_compose "$2"
    ;;
  *) usage ;;
esac
