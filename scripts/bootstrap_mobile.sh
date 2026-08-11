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

# Notifications push : Android 13+ exige que la permission soit DÉCLARÉE dans
# le manifeste (la demande à l'exécution, elle, passe par Firebase Messaging).
# Le dossier android/ étant généré, on répare le manifeste à chaque bootstrap.
MANIFEST="android/app/src/main/AndroidManifest.xml"
if ! grep -q "android.permission.POST_NOTIFICATIONS" "$MANIFEST"; then
  sed -i.bak 's|<application|<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
  echo "Permission POST_NOTIFICATIONS ajoutée à $MANIFEST"
fi

echo "── Dépendances ─────────────────────────────────────────────────────"
flutter pub get

echo "── Analyse statique ────────────────────────────────────────────────"
flutter analyze

echo ""
echo "Terminé. Lancer l'application :"
echo "  cd apps/mobile"
echo "  flutter run --dart-define=CARLYS_FLAVOR=development \\"
echo "              --dart-define=CARLYS_API_BASE_URL=http://localhost:3000"
echo ""
echo "Notifications push (facultatif) : copier config/firebase.example.json"
echo "vers config/firebase.json (ignoré par git), y reporter les valeurs de"
echo "google-services.json, puis ajouter au lancement :"
echo "              --dart-define-from-file=config/firebase.json"
