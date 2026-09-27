#!/usr/bin/env bash
# La CI de ce commit est-elle verte ? Verdict de workflows GitHub Actions
# pour un sha, en attendant ceux qui tournent encore.
#
#   scripts/ci/verdict_ci.sh <sha> <workflow.yml> [<workflow.yml>…]
#
# POURQUOI CE SCRIPT EXISTE. images-publish publiait `sha-…` sans lire aucun
# verdict : douze commits dont api-ci était ROUGE ont eu leurs images, donc
# pouvaient partir en recette par la mise à jour automatique — migration
# cassée comprise (audit du 25/09, 12c471e : « P3006 … failed to apply
# cleanly »). Le lien bêta de mobile-recette faisait de même avec mobile-ci
# (0cbc25d : analyse rouge, APK publié). Ce script est le verrou commun des
# deux : il rend 0 seulement si chaque workflow nommé est vert pour ce code.
#
# « POUR CE CODE », ET PAS SEULEMENT « POUR CE SHA ». Les CI du dépôt sont
# filtrées par `paths` : un commit qui ne touche que docs/ ne déclenche pas
# api-ci. Se contenter de « pas d'exécution = rien à dire » laisserait passer
# la suite A (api rouge) puis B (docs seules) : les images de B portent le
# code d'API de A, et B n'a aucun api-ci. Le verdict qui compte est donc celui
# de l'ANCÊTRE LE PLUS PROCHE (le sha lui-même compris) qui a une exécution de
# ce workflow — c'est lui qui a jugé l'état du code que B embarque.
#
# À UNE CONDITION : que rien de ce que le workflow surveille (ses chemins
# `on.push.paths`, lus au commit jugé) n'ait bougé entre cet ancêtre et le sha.
# Une poussée de plusieurs commits d'un coup n'a qu'une exécution, sur sa
# tête : elle juge la TÊTE, pas les commits du milieu. Poussés ensemble, X1
# (casse l'API) puis X2 (docs) : api-ci tourne sur X2 seul. Sans la condition,
# le rattrapage de X1 prenait le verdict de X0, l'ancêtre vert d'avant la
# poussée, et publiait l'API cassée. X1 n'a donc pas de verdict : bloquant,
# comme un historique hors de portée.
#
# CE QUI VAUT « VERT » : success, skipped, neutral. Tout le reste d'une
# exécution TERMINÉE est rouge, `cancelled` compris : un commit dont la CI a
# été annulée (rafale de poussées, concurrency) n'a rien prouvé. Le message dit
# comment rattraper — relancer le workflow sur ce commit, puis ce qui attendait.
#
# « AUCUNE EXÉCUTION » N'EST CRU QUE SI ON A PU LE VOIR. Un seul appel liste
# les 100 dernières exécutions du workflow (une dizaine de jours au rythme
# d'api-ci) : c'est la FENÊTRE. Tant qu'un ancêtre est plus récent que la plus
# vieille exécution de la fenêtre, n'y trouver aucune exécution prouve qu'il
# n'en a pas. Au-delà — le rattrapage d'un commit d'il y a deux semaines —
# l'absence ne prouve plus rien : la première rédaction concluait pourtant
# « sans objet », et publiait les images d'un commit ROUGE sorti de la
# fenêtre. Hors fenêtre, chaque ancêtre est donc demandé par son sha exact
# (`head_sha`), sans fenêtre ; et si VERDICT_CI_REQUETES_MAX questions
# n'ont rien trouvé, le verdict est « historique hors de portée » : BLOQUANT,
# comme un rouge. « Sans objet » (non bloquant) ne reste qu'au cas prouvé :
# aucun ancêtre jugé, et tous étaient à portée.
#
# Codes de retour :
#   0  tous verts (ou sans objet)
#   1  au moins un rouge
#   2  pas de verdict : délai dépassé (au moins un tournait encore),
#      historique hors de portée, ou code jamais jugé (commit du milieu d'une
#      poussée groupée)
#   3  mauvaise utilisation
#
# Variables :
#   GITHUB_REPOSITORY       propriétaire/dépôt (posé par GitHub Actions)
#   GH_TOKEN                jeton pour `gh api` (droit `actions: read`)
#   VERDICT_CI_DELAI        attente maximale, en secondes (défaut 1800)
#   VERDICT_CI_PAUSE        entre deux relevés, en secondes (défaut 20)
#   VERDICT_CI_PROFONDEUR   ancêtres explorés (défaut 300)
#   VERDICT_CI_REQUETES_MAX questions exactes (hors fenêtre) par workflow
#                           avant « hors de portée » (défaut 60)
#   VERDICT_CI_LISTER       commande qui liste les exécutions d'un workflow ;
#                           défaut : l'API GitHub. Sert aux tests
#                           (scripts/ci/tests/verdict_ci_test.sh). Elle reçoit
#                           le nom du fichier du workflow, et un sha pour une
#                           question exacte. Première ligne : « #couvre »,
#                           tabulation, puis 0 si la liste est COMPLÈTE, sinon
#                           la date (secondes epoch) de la plus vieille
#                           exécution listée. Puis une ligne par exécution :
#                           id, sha, status, conclusion, url, séparés par des
#                           tabulations. Une conclusion encore inconnue
#                           s'écrit « - », jamais vide : la tabulation est un
#                           blanc pour `read`, deux d'affilée n'en font
#                           qu'une et décaleraient les champs.
set -euo pipefail

DELAI="${VERDICT_CI_DELAI:-1800}"
PAUSE="${VERDICT_CI_PAUSE:-20}"
PROFONDEUR="${VERDICT_CI_PROFONDEUR:-300}"
REQUETES_MAX="${VERDICT_CI_REQUETES_MAX:-60}"
# Une exécution naît APRÈS son commit (la poussée suit le commit). La marge
# couvre une horloge de poste en avance, qui daterait le commit trop tard et
# ferait croire la fenêtre assez longue.
MARGE_S=86400

usage() {
  sed -n '5p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 3
}

[ "$#" -ge 2 ] || usage
SHA="$1"; shift
WORKFLOWS=("$@")

# Les exécutions d'un workflow, les plus récentes d'abord : les 100
# dernières (la fenêtre), ou celles d'un sha exact. Celles d'une pull request
# sont écartées APRÈS la page : elles testent le commit de FUSION, pas ce sha,
# mais elles comptent dans l'étendue de la fenêtre.
lister_via_github() {
  [ -n "${GITHUB_REPOSITORY:-}" ] || { echo "GITHUB_REPOSITORY absent." >&2; return 1; }
  local filtre=()
  [ -z "${2-}" ] || filtre=(-f "head_sha=$2")
  gh api -X GET "repos/$GITHUB_REPOSITORY/actions/workflows/$1/runs" -f per_page=100 "${filtre[@]}" \
    --jq '(if .total_count <= (.workflow_runs | length) then "#couvre\t0"
           else "#couvre\t\(.workflow_runs[-1].created_at | fromdateiso8601)" end),
          (.workflow_runs[] | select(.event != "pull_request")
           | [.id, .head_sha, .status, (.conclusion // "-"), .html_url] | @tsv)'
}
LISTER="${VERDICT_CI_LISTER:-lister_via_github}"

# Le sha complet puis ses ancêtres, du plus proche au plus lointain. Hors
# d'un dépôt git (ou sha inconnu), le sha seul : on perd la règle de l'ancêtre,
# jamais le verdict du commit lui-même.
if COMPLET="$(git rev-parse --verify --quiet "${SHA}^{commit}" 2>/dev/null)"; then
  mapfile -t ANCETRES < <(git rev-list --max-count="$PROFONDEUR" "$COMPLET")
else
  echo "::warning::$SHA inconnu du dépôt local : seul ce commit est examiné, pas ses ancêtres."
  COMPLET="$SHA"
  ANCETRES=("$SHA")
fi

# L'exécution la plus récente d'un commit parmi des lignes d'exécutions :
# identifiant le plus grand. Une relance garde son identifiant ; son état est
# celui de la relance. Les lignes « # » (en-tête) ne sont pas des exécutions.
derniere_execution() {
  printf '%s\n' "$1" | awk -F'\t' -v s="$2" '$1 !~ /^#/ && $2 == s' | sort -t$'\t' -k1,1n | tail -n 1
}

# `a_portee <couvre> <sha>` — vrai si la fenêtre remonte assez loin pour que
# l'absence d'exécution de ce commit y soit une preuve. Sans date connue (sha
# hors du dépôt local), jamais.
a_portee() {
  local couvre="$1" date_commit
  [ "$couvre" = 0 ] && return 0
  case "$couvre" in '' | *[!0-9]*) return 1 ;; esac
  date_commit="$(git log -1 --format=%ct "$2" 2>/dev/null)" || return 1
  [ -n "$date_commit" ] && [ "$couvre" -le $((date_commit - MARGE_S)) ]
}

# Les chemins `on.push.paths` d'un workflow, un par ligne, lus au commit jugé.
# Lecture volontairement bête du YAML (aucun outil à installer), calée sur la
# forme des workflows du dépôt : `on:` en colonne 0, `push:` à deux espaces,
# `paths:` à quatre, les entrées `- '…'` à six. Rien de lu (workflow absent,
# sans filtre, ou d'une autre forme) : aucun chemin, donc tout l'arbre compte —
# l'erreur se fait du côté prudent.
chemins_surveilles() {
  git show "$COMPLET:.github/workflows/$1" 2>/dev/null | awk '
    /^[^ #]/ { on = /^on:/; push = 0; paths = 0; next }
    on && /^  [^ #]/ { push = /^  push:/; paths = 0; next }
    push && /^    [^ #-]/ { paths = /^    paths:/; next }
    paths && /^      - / { sub(/^      - */, ""); gsub(/["'\'']/, ""); print }'
}

# `code_inchange <workflow> <ancêtre>` — vrai si rien de ce que le workflow
# surveille n'a bougé de l'ancêtre au commit jugé. `diff-tree` ne compare que
# les arbres : il marche aussi dans un clone partiel sans blobs (le lien bêta
# de mobile-recette), où seul le workflow lui-même doit être présent.
code_inchange() {
  local chemins=() p
  while IFS= read -r p; do chemins+=(":(glob)$p"); done < <(chemins_surveilles "$1")
  git diff-tree --quiet -r "$2" "$COMPLET" -- ${chemins[@]+"${chemins[@]}"}
}

# `verdict_de <workflow>` écrit « <état> <sha jugé> <url> » : état parmi
# vert, rouge:<conclusion>, en_cours, absent, hors_portee, jamais_juge, erreur.
verdict_de() {
  local wf="$1" fenetre couvre ancetre ligne exactes sha status conclusion url requetes=0
  fenetre="$("$LISTER" "$wf")" || { printf 'erreur - -'; return 0; }
  couvre="$(printf '%s\n' "$fenetre" | awk -F'\t' '$1 == "#couvre" { print $2; exit }')"
  for ancetre in "${ANCETRES[@]}"; do
    ligne="$(derniere_execution "$fenetre" "$ancetre")"
    if [ -z "$ligne" ] && ! a_portee "$couvre" "$ancetre"; then
      # Hors de la fenêtre : la question exacte, par sha.
      if [ "$requetes" -ge "$REQUETES_MAX" ]; then
        printf 'hors_portee %s -' "$ancetre"
        return 0
      fi
      requetes=$((requetes + 1))
      exactes="$("$LISTER" "$wf" "$ancetre")" || { printf 'erreur - -'; return 0; }
      ligne="$(derniere_execution "$exactes" "$ancetre")"
    fi
    [ -n "$ligne" ] || continue
    if [ "$ancetre" != "$COMPLET" ] && ! code_inchange "$wf" "$ancetre"; then
      printf 'jamais_juge %s -' "$ancetre"
      return 0
    fi
    IFS=$'\t' read -r _ sha status conclusion url <<< "$ligne"
    if [ "$status" != completed ]; then
      printf 'en_cours %s %s' "$sha" "$url"
    else
      case "$conclusion" in
        success | skipped | neutral) printf 'vert %s %s' "$sha" "$url" ;;
        *) printf 'rouge:%s %s %s' "${conclusion:-inconnue}" "$sha" "$url" ;;
      esac
    fi
    return 0
  done
  printf 'absent - -'
}

resume() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
}

debut="$(date +%s)"
resume "### Verdict de la CI pour \`${COMPLET:0:12}\`"
# Les verdicts ACQUIS (vert, sans objet) ne sont pas redemandés à chaque
# relevé : seul un workflow en cours doit l'être. Sans cela, un workflow jugé
# hors fenêtre referait ses questions exactes toutes les ${PAUSE} s.
declare -A ACQUIS=()
while :; do
  attente=()
  rouges=()
  hors=()
  lignes=()
  for wf in "${WORKFLOWS[@]}"; do
    verdict="${ACQUIS[$wf]:-$(verdict_de "$wf")}"
    read -r etat juge url <<< "$verdict"
    case "$etat" in
      vert)     ACQUIS[$wf]="$verdict"; lignes+=("✓ $wf : vert (jugé sur ${juge:0:12}) $url") ;;
      absent)   ACQUIS[$wf]="$verdict"; lignes+=("· $wf : aucune exécution sur ce commit ni ses $PROFONDEUR ancêtres — sans objet") ;;
      en_cours) attente+=("$wf"); lignes+=("… $wf : en cours sur ${juge:0:12} $url") ;;
      erreur)   attente+=("$wf"); lignes+=("? $wf : exécutions illisibles (API injoignable ?) — nouvel essai") ;;
      rouge:*)  rouges+=("$wf"); lignes+=("✗ $wf : ${etat#rouge:} sur ${juge:0:12} $url") ;;
      hors_portee) hors+=("$wf"); lignes+=("✗ $wf : historique hors de portée — aucune exécution dans les 100 dernières ni sur les $REQUETES_MAX ancêtres demandés un par un, jusqu'à ${juge:0:12}") ;;
      jamais_juge) hors+=("$wf"); lignes+=("✗ $wf : code jamais jugé — aucune exécution sur ${COMPLET:0:12}, et ce que $wf surveille a changé depuis ${juge:0:12}, le dernier commit jugé (commit du milieu d'une poussée groupée ?)") ;;
    esac
  done

  if [ "${#rouges[@]}" -gt 0 ] || [ "${#hors[@]}" -gt 0 ] || [ "${#attente[@]}" -eq 0 ]; then
    printf '%s\n' "${lignes[@]}"
    for l in "${lignes[@]}"; do resume "- $l"; done
    break
  fi
  if [ "$(($(date +%s) - debut))" -ge "$DELAI" ]; then
    printf '%s\n' "${lignes[@]}"
    for l in "${lignes[@]}"; do resume "- $l"; done
    echo "::error title=CI toujours en cours::Après ${DELAI} s, ${attente[*]} n'a pas rendu de verdict pour ${COMPLET:0:12}. Relancer ce job une fois la CI terminée."
    exit 2
  fi
  echo "En attente de : ${attente[*]} (relevé toutes les ${PAUSE} s)"
  sleep "$PAUSE"
done

if [ "${#rouges[@]}" -gt 0 ]; then
  echo "::error title=CI rouge::${rouges[*]} n'est pas vert pour le code de ${COMPLET:0:12} (voir ci-dessus). Rien n'est publié. Rattrapage : corriger et pousser ; ou, si l'échec ne tenait pas au code (panne de registre, runner, annulation), relancer ce workflow sur le commit jugé, puis relancer ce job."
  exit 1
fi
if [ "${#hors[@]}" -gt 0 ]; then
  echo "::error title=CI introuvable::${hors[*]} : aucun verdict pour le code de ${COMPLET:0:12} (voir ci-dessus). Rien n'est publié : ni une absence d'exécution dans un historique illisible, ni le verdict d'un ancêtre dont le code diffère, ne prouvent quoi que ce soit. Rattrapage : publier plutôt la tête de sa poussée, qui a son verdict ; relancer ce workflow sur ce commit s'il le permet (Run workflow), puis ce job ; ou, après avoir vérifié la CI de ce code à la main, relancer avec « ignorer_ci »."
  exit 2
fi
echo "CI verte pour ${COMPLET:0:12}."
