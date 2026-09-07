#!/usr/bin/env bash
# Engendre les dossiers de plateformes Flutter (android/, ios/) SANS abîmer
# l'arbre versionné. Un seul endroit sait réparer les effets de bord de
# `flutter create` : le poste de développement (bootstrap_mobile.sh) et la CI
# (demo-apk.yml) passent tous les deux par ici.
#
# Usage : scripts/mobile_platforms.sh <plateformes>
#   ex. « android » (CI de l'APK de démo) ou « android,ios » (poste).
#
# `flutter create` sur un projet EXISTANT a deux effets de bord, mesurés sur
# ce dépôt en Flutter 3.44.9 :
#
#   1. Il ÉCRASE pubspec.lock. Sans `--no-pub`, il enchaîne un `pub get` qui
#      résout tout à neuf : 28 paquets déplacés par rapport au lock du dépôt,
#      un ajouté — dont drift 2.34.3→2.34.4 et drift_dev 2.34.5→2.34.6 (le
#      générateur qui tourne juste après), dio 5.11.0→5.11.1 et xml
#      6.6.1→7.0.1, un saut de MAJEURE. Avec `--no-pub`, il laisse à la place
#      le lock du GABARIT (un JSON de 73 lignes), que
#      `pub get --enforce-lockfile` refuse ensuite avec le code 65.
#      Dans les deux cas, l'artefact n'est plus construit sur l'arbre de
#      dépendances éprouvé par mobile-ci. On prend donc `--no-pub` — la
#      résolution superflue en moins — et on remet le lock à l'octet près.
#
#   2. Il recrée test/widget_test.dart, le test du GABARIT, qui référence un
#      `MyApp` inexistant ici : deux erreurs d'analyse garanties dès qu'une
#      vérification tourne derrière.
set -euo pipefail

PLATFORMS="${1:?Plateformes attendues, par exemple « android » ou « android,ios »}"

cd "$(dirname "$0")/../apps/mobile"

# Sauvegarde AVANT création, restauration par trap : le lock revient à son
# état d'origine même si `flutter create` échoue en cours de route. On
# restaure une COPIE plutôt que `git checkout --` : un lock légitimement
# modifié dans l'arbre de travail (montée de dépendance en cours) doit
# survivre au bootstrap, pas être écrasé par la version du dépôt.
#
# `cp` vers la destination EXISTANTE, jamais `mv` : `mv` déplace l'inode de la
# sauvegarde, ses droits compris, et `mktemp` crée en 0600. Le lock versionné
# repartait donc en 0600 à CHAQUE exécution (mesuré : 644 → 600, md5 inchangé,
# aussi bien après une création réussie qu'après un échec de `flutter create`),
# un changement que git ne suit pas et que personne ne voyait. `cp` écrit dans
# le fichier déjà là et lui laisse ses droits d'origine.
LOCK_BACKUP=""
restaurer_lock() {
  if [ -n "$LOCK_BACKUP" ] && [ -f "$LOCK_BACKUP" ]; then
    cp "$LOCK_BACKUP" pubspec.lock && rm -f "$LOCK_BACKUP"
  fi
}
if [ -f pubspec.lock ]; then
  LOCK_BACKUP="$(mktemp)"
  cp pubspec.lock "$LOCK_BACKUP"
  trap restaurer_lock EXIT
fi

flutter create --no-pub --org com.carlys --project-name carlys_mobile \
  --platforms "$PLATFORMS" .

restaurer_lock
LOCK_BACKUP=""
trap - EXIT

# On ne retire que le test du gabarit, et seulement s'il n'est pas suivi par
# git : un fichier du même nom qui serait un jour versionné resterait intouché.
if [ -f test/widget_test.dart ] &&
  ! git ls-files --error-unmatch test/widget_test.dart >/dev/null 2>&1; then
  rm test/widget_test.dart
fi
