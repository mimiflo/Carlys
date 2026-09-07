#!/usr/bin/env bash
# Vérification complète du projet Flutter : à exécuter avant tout commit.
#
# Reproduit EXACTEMENT `.github/workflows/mobile-ci.yml`, dans le même ordre.
# C'est le point : `flutter analyze && flutter test` — longtemps la consigne —
# laisse passer ce que la CI refuse. `dart format --set-exit-if-changed` a fait
# tomber une CI verte en local ; cette liste ne doit donc pas diverger.
#
# « EXACTEMENT » se relit bloc `run:` par bloc `run:` : dépendances, génération
# de code, formatage, analyse, tests — les cinq commandes sont identiques au
# caractère près. `--enforce-lockfile` a longtemps manqué ici, sous couvert de
# « seule différence assumée » : une différence assumée reste un filet troué.
# Mesuré sur un paquet au lock désynchronisé : la commande de la CI rend 65
# (« Unable to satisfy `pubspec.yaml` using `pubspec.lock` ») là où un `pub get`
# nu rend 0 EN RÉÉCRIVANT LE LOCK EN SILENCE. Le développeur voyait donc un vert
# local complet, ne commitait pas le lock réécrit, et poussait un job rouge.
# Mettre le lock à jour reste possible — c'est `flutter pub get` sans l'option,
# suivi du commit du lock, ce que dit le message d'échec ci-dessous.
#
# Le seul écart restant avec la CI est le SDK lui-même : l'avertissement de
# version ci-dessous le couvre.
#
# Un bloc, et un seul, ne vient PAS de la CI : les tailles de fichiers, en
# tête. Ce n'est pas une divergence au sens ci-dessus — les cinq commandes de
# la CI restent identiques, contiguës et dans le même ordre juste après —,
# c'est un AJOUT local qui va dans le sens sûr : un vert ici reste un vert
# là-bas. Il est en tête parce qu'il coûte quelques millisecondes et qu'il
# n'a aucune raison de faire attendre le développeur derrière deux minutes de
# tests. Et il est écrit en shell parce que l'analyseur Dart n'a pas de règle
# de longueur de fichier : `max_lines_per_file` rend « isn't a recognized
# lint rule ».
#
# Note : `dart format` et la règle de lint `require_trailing_commas` peuvent se
# contredire sur un appel qui tient de justesse sur deux lignes. La forme qui
# satisfait les deux est l'appel ÉCLATÉ, un argument par ligne, virgule finale
# comprise — le formateur la conserve alors telle quelle.
set -euo pipefail

# Retenu AVANT le `cd` : `$0` est souvent relatif au répertoire d'appel, et
# ne désignerait plus rien une fois qu'on a changé de dossier.
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPTS_DIR/../apps/mobile"

echo "── Version Flutter ─────────────────────────────────────────────────"
# La CI installe la version épinglée dans apps/mobile/.flutter-version
# (source unique, lue aussi par mobile-ci.yml et demo-apk.yml). Un écart
# n'arrête pas le script — mais il enlève au vert local sa valeur de preuve.
PINNED="$(cat .flutter-version)"
ACTUAL="$(flutter --version 2>/dev/null | sed -n 's/^Flutter \([^ ]*\).*/\1/p' || true)"
if [ "$ACTUAL" = "$PINNED" ]; then
  echo "Flutter $ACTUAL — la version épinglée."
else
  echo "⚠⚠⚠ Flutter local « ${ACTUAL:-introuvable} » ≠ « $PINNED » épinglé" \
    "par apps/mobile/.flutter-version : un résultat vert ici ne prouve" \
    "rien sur la CI (mobile-ci.yml)."
fi

echo "── Tailles de fichiers (règle du dépôt, hors CI) ───────────────────"
"$SCRIPTS_DIR/check_mobile_file_sizes.sh"

echo "── Dépendances ─────────────────────────────────────────────────────"
# Le message de pub est exact mais muet sur la suite : ici, la suite est de
# COMMITER le lock, sans quoi la CI retombera sur le même 65.
#
# Le conseil ne vaut QUE pour le 65 (« Unable to satisfy `pubspec.yaml` using
# `pubspec.lock` »). `pub get` échoue aussi pour de tout autres raisons —
# mesuré sur un pubspec.yaml malformé : code 1, « Unexpected child "rxdart"
# found under "flutter" ». Envoyer alors le développeur relancer `pub get` et
# committer le lock, c'est le lancer sur une piste fausse pendant que la vraie
# cause est déjà à l'écran. On conditionne donc le message au code rendu.
flutter pub get --enforce-lockfile || {
  CODE=$?
  echo ""
  if [ "$CODE" -eq 65 ]; then
    echo "✗ pubspec.lock ne satisfait plus pubspec.yaml — la CI (mobile-ci.yml)"
    echo "  échouera de la même façon, avec ce même code $CODE."
    echo "  Résoudre, RELIRE le résultat, puis committer le lock :"
    echo "      (cd apps/mobile && flutter pub get)"
    echo "      git add apps/mobile/pubspec.lock"
  else
    echo "✗ flutter pub get a échoué (code $CODE), voir la sortie ci-dessus."
  fi
  exit "$CODE"
}

echo "── Génération de code (Drift) ──────────────────────────────────────"
dart run build_runner build

echo "── Formatage ───────────────────────────────────────────────────────"
# Les fichiers générés sont exclus : ce n'est pas nous qui les écrivons.
dart format --output=none --set-exit-if-changed \
  $(find lib test -name '*.dart' ! -name '*.g.dart')

echo "── Analyse statique ────────────────────────────────────────────────"
flutter analyze

echo "── Tests ───────────────────────────────────────────────────────────"
flutter test

echo ""
echo "Toutes les vérifications Flutter sont passées."
