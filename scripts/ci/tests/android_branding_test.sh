#!/usr/bin/env bash
# Essai de scripts/android_branding.sh, sans Flutter ni SDK Android.
#
# android/ et ios/ ne sont pas versionnés : ce script EST la configuration
# native (nom, icône, permissions, Health Connect, HealthKit). Il tourne sur
# un arbre engendré par `flutter create` — reproduit ici dans ses seules
# parties que le script lit (forme du gabarit de Flutter 3.44) — et doit :
#   1. poser ce que Health Connect et HealthKit exigent, en LECTURE seule ;
#   2. être IDEMPOTENT : relancé, il ne change plus un octet (bootstrap
#      relancé sur un poste, ou CI qui le rejoue).
set -euo pipefail

RACINE="$(cd "$(dirname "$0")/../../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/scripts" "$TMP/apps/mobile"
cp "$RACINE/scripts/android_branding.sh" "$TMP/scripts/"
cp -r "$RACINE/apps/mobile/launcher" "$TMP/apps/mobile/"
cd "$TMP/apps/mobile"

mkdir -p android/app/src/main/kotlin/com/carlys/carlys_mobile android/app/src/debug \
  ios/Runner ios/Runner.xcodeproj
cat > android/app/src/main/AndroidManifest.xml <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="carlys_mobile"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
XML
cat > android/app/src/debug/AndroidManifest.xml <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
</manifest>
XML
cat > android/app/build.gradle.kts <<'KTS'
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        minSdk = flutter.minSdkVersion
    }
}
KTS
cat > android/app/src/main/kotlin/com/carlys/carlys_mobile/MainActivity.kt <<'KT'
package com.carlys.carlys_mobile

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
KT
cat > ios/Runner/Info.plist <<'PLIST'
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>Carlys Mobile</string>
</dict>
</plist>
PLIST
printf '\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n%.0s' 1 2 3 > ios/Runner.xcodeproj/project.pbxproj

echec() {
  echo "✗ $1" >&2
  exit 1
}

bash ../../scripts/android_branding.sh > /dev/null
empreinte() { find android ios -type f -print0 | sort -z | xargs -0 sha256sum; }
premiere="$(empreinte)"
bash ../../scripts/android_branding.sh > /dev/null
[ "$(empreinte)" = "$premiere" ] || echec "deuxième passage : des fichiers ont changé (non idempotent)"

MANIFEST=android/app/src/main/AndroidManifest.xml
for permission in READ_STEPS READ_WEIGHT READ_BODY_FAT; do
  [ "$(grep -c "android.permission.health.$permission\"" "$MANIFEST")" -eq 1 ] ||
    echec "permission $permission absente ou en double"
done
! grep -q 'android.permission.health.WRITE_' "$MANIFEST" || echec "une permission d'ÉCRITURE Health Connect est déclarée"
grep -q '<package android:name="com.google.android.apps.healthdata"/>' "$MANIFEST" ||
  echec "<queries> ne voit pas le paquet Health Connect"
[ "$(grep -c 'androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE' "$MANIFEST")" -eq 2 ] ||
  echec "l'intention de justification doit figurer dans <queries> ET sur l'activité"
grep -q 'android.intent.action.VIEW_PERMISSION_USAGE' "$MANIFEST" || echec "alias VIEW_PERMISSION_USAGE absent"
grep -q 'android:permission="android.permission.START_VIEW_PERMISSION_USAGE"' "$MANIFEST" ||
  echec "l'alias doit être protégé par START_VIEW_PERMISSION_USAGE"
python3 -c 'import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])' "$MANIFEST" ||
  echec "manifeste XML mal formé"

ACTIVITY=android/app/src/main/kotlin/com/carlys/carlys_mobile/MainActivity.kt
grep -q '^package com.carlys.carlys_mobile$' "$ACTIVITY" || echec "paquet de MainActivity perdu"
grep -q 'class MainActivity : FlutterFragmentActivity()' "$ACTIVITY" || echec "MainActivity n'étend pas FlutterFragmentActivity"
grep -q '"/sante-connectee"' "$ACTIVITY" || echec "la justification n'ouvre pas /sante-connectee"
grep -q 'minSdk = maxOf(flutter.minSdkVersion, 26)' android/app/build.gradle.kts || echec "minSdk < 26"

grep -q '<key>NSHealthShareUsageDescription</key>' ios/Runner/Info.plist || echec "motif de lecture Santé absent"
! grep -q 'NSHealthUpdateUsageDescription' ios/Runner/Info.plist || echec "motif d'ÉCRITURE Santé déclaré"
grep -q '<key>com.apple.developer.healthkit</key>' ios/Runner/Runner.entitlements || echec "droits HealthKit absents"
[ "$(grep -c 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' ios/Runner.xcodeproj/project.pbxproj)" -eq 3 ] ||
  echec "les trois configurations de Runner doivent désigner Runner.entitlements"

echo "✓ android_branding.sh : Health Connect et HealthKit en lecture, idempotent"
