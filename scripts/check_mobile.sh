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
# Note : `dart format` et la règle de lint `require_trailing_commas` peuvent se
# contredire sur un appel qui tient de justesse sur deux lignes. La forme qui
# satisfait les deux est l'appel ÉCLATÉ, un argument par ligne, virgule finale
# comprise — le formateur la conserve alors telle quelle.
set -euo pipefail

cd "$(dirname "$0")/../apps/mobile"

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

echo "── Dépendances ─────────────────────────────────────────────────────"
# Le message de pub est exact mais muet sur la suite : ici, la suite est de
# COMMITER le lock, sans quoi la CI retombera sur le même 65.
flutter pub get --enforce-lockfile || {
  CODE=$?
  echo ""
  echo "✗ pubspec.lock ne satisfait plus pubspec.yaml — la CI (mobile-ci.yml)"
  echo "  échouera de la même façon, avec ce même code $CODE."
  echo "  Résoudre, RELIRE le résultat, puis committer le lock :"
  echo "      (cd apps/mobile && flutter pub get)"
  echo "      git add apps/mobile/pubspec.lock"
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
