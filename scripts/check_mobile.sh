#!/usr/bin/env bash
# Vérification complète du projet Flutter : à exécuter avant tout commit.
#
# Reproduit EXACTEMENT `.github/workflows/mobile-ci.yml`, dans le même ordre.
# C'est le point : `flutter analyze && flutter test` — longtemps la consigne —
# laisse passer ce que la CI refuse. `dart format --set-exit-if-changed` a fait
# tomber une CI verte en local ; cette liste ne doit donc pas diverger.
#
# Note : `dart format` et la règle de lint `require_trailing_commas` peuvent se
# contredire sur un appel qui tient de justesse sur deux lignes. La forme qui
# satisfait les deux est l'appel ÉCLATÉ, un argument par ligne, virgule finale
# comprise — le formateur la conserve alors telle quelle.
set -euo pipefail

cd "$(dirname "$0")/../apps/mobile"

echo "── Dépendances ─────────────────────────────────────────────────────"
flutter pub get

echo "── Génération de code (Freezed, Riverpod, Drift, json) ─────────────"
dart run build_runner build --delete-conflicting-outputs

echo "── Formatage ───────────────────────────────────────────────────────"
# Les fichiers générés sont exclus : ce n'est pas nous qui les écrivons.
dart format --output=none --set-exit-if-changed \
  $(find lib test -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart')

echo "── Analyse statique ────────────────────────────────────────────────"
flutter analyze

echo "── Tests ───────────────────────────────────────────────────────────"
flutter test

echo ""
echo "Toutes les vérifications Flutter sont passées."
