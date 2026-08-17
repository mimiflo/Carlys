#!/usr/bin/env bash
# Prépare l'application Flutter : dossiers de plateformes + dépendances.
set -euo pipefail

# Chemin ABSOLU des scripts, résolu AVANT le cd : "$0" est relatif à
# l'endroit d'où l'on a lancé le script, plus valable ensuite.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR/../apps/mobile"

command -v flutter >/dev/null || {
  echo "Le SDK Flutter est requis : https://docs.flutter.dev/get-started/install"
  exit 1
}

echo "── Génération des dossiers de plateformes (android/, ios/) ─────────"
flutter create --org com.carlys --project-name carlys_mobile \
  --platforms android,ios .

echo "── Identité Carlys (nom, icône, permission de notification) ───────"
"$SCRIPT_DIR/android_branding.sh"

echo "── Dépendances ─────────────────────────────────────────────────────"
flutter pub get

# Le code engendré (Drift) n'est PAS versionné : sur un clone frais il n'existe
# pas, et `app_database.dart` le déclare en `part`. Sans cette étape, l'analyse
# qui suit échoue sur deux cents erreurs dont la cause tient en une ligne.
echo "── Génération de code (Drift) ──────────────────────────────────────"
dart run build_runner build --delete-conflicting-outputs

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
