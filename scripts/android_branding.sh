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

# ── HTTP en clair, en DEBUG uniquement ──────────────────────────────────────
#
# Au-delà d'API 28, Android refuse le trafic en clair : une API locale servie
# en `http://10.0.2.2:3000` (l'hôte, vu depuis l'émulateur) est rejetée avec
# « CLEARTEXT communication not permitted by network security policy ». Le
# manifeste de debug engendré par `flutter create` ne déclare que la
# permission INTERNET, donc rien ne l'autorise.
#
# La dérogation vit dans le jeu de sources `debug/` : elle N'ENTRE JAMAIS
# dans un APK de release, où le trafic en clair reste interdit.
mkdir -p android/app/src/debug/res/xml
cat > android/app/src/debug/res/xml/network_security_config.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<!--
  DÉVELOPPEMENT UNIQUEMENT. Ce fichier appartient au jeu de sources `debug`
  et n'est pas embarqué dans une release : le trafic en clair y demeure
  interdit. Il autorise l'API locale — 10.0.2.2 depuis l'émulateur, l'IP du
  poste depuis un téléphone du même réseau — servie sans TLS.
-->
<network-security-config>
  <base-config cleartextTrafficPermitted="true" />
</network-security-config>
XML

DEBUG_MANIFEST="android/app/src/debug/AndroidManifest.xml"
if ! grep -q "networkSecurityConfig" "$DEBUG_MANIFEST"; then
  # Fusion de manifeste : l'attribut rejoint le <application> du manifeste
  # principal, qui n'en déclare aucun — donc aucun conflit à arbitrer.
  sed -i.bak 's|</manifest>|    <application\n        android:networkSecurityConfig="@xml/network_security_config" />\n</manifest>|' "$DEBUG_MANIFEST"
  rm -f "$DEBUG_MANIFEST.bak"
fi

# iOS, si le dossier a été généré : même nom sous l'icône.
PLIST="ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  sed -i.bak '/<key>CFBundleDisplayName<\/key>/{n;s|<string>.*</string>|<string>Carlys</string>|;}' "$PLIST"
  rm -f "$PLIST.bak"

  # Scanner de code ami : iOS refuse d'ouvrir la caméra sans motif déclaré
  # (l'app crasherait au premier scan). Android n'a rien à déclarer ici, le
  # manifeste de mobile_scanner s'en charge par fusion. L'ancre est le
  # DERNIER </dict> du plist — awk, parce que sed ne sait pas dire
  # « dernier » et que Git Bash sous Windows n'a pas python.
  if ! grep -q "NSCameraUsageDescription" "$PLIST"; then
    awk '
      { lines[NR] = $0 }
      /<\/dict>/ { last = NR }
      END {
        for (i = 1; i <= NR; i++) {
          if (i == last) {
            print "\t<key>NSCameraUsageDescription</key>"
            print "\t<string>La caméra sert à scanner le code ami d’un profil Carlys.</string>"
          }
          print lines[i]
        }
      }' "$PLIST" > "$PLIST.tmp" && mv "$PLIST.tmp" "$PLIST"
  fi
fi

echo "Identité Carlys appliquée : nom, icône, permission de notification."
