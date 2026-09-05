#!/usr/bin/env bash
# Vérification complète du projet Flutter : à exécuter avant tout commit.
#
# Reproduit EXACTEMENT `.github/workflows/mobile-ci.yml`, dans le même ordre.
# C'est le point : `flutter analyze && flutter test` — longtemps la consigne —
# laisse passer ce que la CI refuse. `dart format --set-exit-if-changed` a fait
# tomber une CI verte en local ; cette liste ne doit donc pas diverger.
# Seule différence assumée : la CI passe `--enforce-lockfile` à `pub get`
# (le lock y est contraignant) ; en local, `pub get` doit pouvoir mettre le
# lock à jour quand le pubspec change. L'avertissement de version ci-dessous
# couvre l'autre écart possible avec la CI : le SDK lui-même.
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
flutter pub get

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
