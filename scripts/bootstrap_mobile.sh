#!/usr/bin/env bash
# Prépare l'application Flutter : dossiers de plateformes + dépendances.
set -euo pipefail

cd "$(dirname "$0")/../apps/mobile"

command -v flutter >/dev/null || {
  echo "Le SDK Flutter est requis : https://docs.flutter.dev/get-started/install"
  exit 1
}

echo "── Génération des dossiers de plateformes (android/, ios/) ─────────"
flutter create --org com.carlys --project-name carlys_mobile \
  --platforms android,ios .

echo "── Dépendances ─────────────────────────────────────────────────────"
flutter pub get

echo "── Analyse statique ────────────────────────────────────────────────"
flutter analyze

echo ""
echo "Terminé. Lancer l'application :"
echo "  cd apps/mobile"
echo "  flutter run --dart-define=CARLYS_FLAVOR=development \\"
echo "              --dart-define=CARLYS_API_BASE_URL=http://localhost:3000"
