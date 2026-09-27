#!/usr/bin/env bash
# Tests : ce que la passe de supervision fait d'elle-même — avancer le clone
# du serveur (_repo.sh, repo_pull) et lancer les tâches quotidiennes
# (_quotidien.sh : balayage des photos, purge des comptes supprimés).
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
  banc_lancer bash -c '. "$0/_common.sh"; "$@"' "$BANC_SERVEUR" "$@"
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

banc_bilan
