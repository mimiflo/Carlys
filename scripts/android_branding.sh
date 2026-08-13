#!/usr/bin/env bash
# Applique l'identité Carlys au dossier android/ GÉNÉRÉ par flutter create :
# nom affiché (« Carlys »), icône de lanceur (le sceau de la marque, déclinée
# dans apps/mobile/launcher/), permission de notification Android 13+.
#
# android/ et ios/ ne sont pas versionnés : l'identité vit ICI et dans
# launcher/ — appelé par scripts/bootstrap_mobile.sh et par la CI demo-apk.
set -euo pipefail

cd "$(dirname "$0")/../apps/mobile"

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "android/ absent — lancer d'abord flutter create (bootstrap_mobile.sh)"
  exit 1
fi

# Nom affiché sous l'icône et dans les applications récentes.
sed -i.bak 's/android:label="[^"]*"/android:label="Carlys"/' "$MANIFEST"
rm -f "$MANIFEST.bak"

# Icône de lanceur : adaptative (API 26+) + héritée, toutes densités.
cp -r launcher/res/. android/app/src/main/res/

# Android 13+ : la permission de notification se DÉCLARE dans le manifeste
# (la demande à l'exécution passe par Firebase Messaging).
if ! grep -q "android.permission.POST_NOTIFICATIONS" "$MANIFEST"; then
  sed -i.bak 's|<application|<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi

# iOS, si le dossier a été généré : même nom sous l'icône.
PLIST="ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  sed -i.bak '/<key>CFBundleDisplayName<\/key>/{n;s|<string>.*</string>|<string>Carlys</string>|;}' "$PLIST"
  rm -f "$PLIST.bak"
fi

echo "Identité Carlys appliquée : nom, icône, permission de notification."
