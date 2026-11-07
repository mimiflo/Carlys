#!/usr/bin/env bash
# Applique l'identité Carlys au dossier android/ GÉNÉRÉ par flutter create :
# nom affiché (« Carlys »), icône de lanceur (le sceau de la marque, déclinée
# dans apps/mobile/launcher/), permission de notification Android 13+,
# appareil photo FACULTATIF, accès au moteur de synthèse vocale, Health
# Connect en lecture (pas, poids, masse grasse) ; et, côté ios/ s'il existe,
# le nom, les motifs d'accès à l'appareil photo, aux photos et à Santé, et la
# capacité HealthKit. Idempotent : le relancer ne change plus rien
# (scripts/ci/tests/android_branding_test.sh).
#
# android/ et ios/ ne sont pas versionnés : l'identité vit ICI et dans
# launcher/ — appelé par scripts/bootstrap_mobile.sh et par la CI mobile-recette.
set -euo pipefail

cd "$(dirname "$0")/../apps/mobile"

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "android/ absent — lancer d'abord scripts/mobile_platforms.sh android" \
    "(ou scripts/bootstrap_mobile.sh, qui l'appelle)"
  exit 1
fi

# Nom affiché sous l'icône et dans les applications récentes.
sed -i.bak 's/android:label="[^"]*"/android:label="Carlys"/' "$MANIFEST"
rm -f "$MANIFEST.bak"

# Icône de lanceur : adaptative (API 26+) + héritée, toutes densités.
cp -r launcher/res/. android/app/src/main/res/

# Android 13+ : la permission de notification se DÉCLARE dans le manifeste
# (la demande à l'exécution passe par Firebase Messaging).
#
# Le saut de ligne dans le remplacement est un VRAI saut de ligne précédé
# d'un antislash, pas « \n » : le sed de macOS (BSD) n'interprète pas « \n »
# dans la partie remplacement et écrivait un « n » littéral — manifeste
# corrompu sur tout poste Mac, et sur le runner macOS de mobile-recette.
if ! grep -q "android.permission.POST_NOTIFICATIONS" "$MANIFEST"; then
  sed -i.bak 's|<application|<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\
    <application|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi

# ── Appareil photo : utile, jamais exigé ────────────────────────────────────
#
# Deux usages : le scan du code ami (mobile_scanner) et la photo d'un repas
# (image_picker). La permission CAMERA arrive par fusion du manifeste de
# mobile_scanner, et image_picker la DEMANDE à l'exécution quand elle est
# déclarée (refus → « camera_access_denied », que l'écran traduit). La
# galerie, elle, ne demande rien : Android 13+ ouvre le sélecteur de photos
# du système, les versions précédentes un sélecteur de fichiers.
#
# Reste à dire que la caméra n'est PAS requise : sinon le Play Store cache
# l'application aux appareils sans caméra (tablettes, Chromebooks), qui
# peuvent pourtant choisir une photo dans la galerie. mobile_scanner le dit
# aussi dans son propre manifeste ; on le dit ICI, pour que la règle ne
# dépende pas d'une bibliothèque qu'on pourrait retirer.
if ! grep -q 'android.hardware.camera"' "$MANIFEST"; then
  sed -i.bak 's|<application|<uses-feature android:name="android.hardware.camera" android:required="false"/>\
    <application|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi

# ── Synthèse vocale : la voix parlée du Mentor ──────────────────────────────
#
# Depuis Android 11, une application ne VOIT un service d'un autre paquet que
# s'il est déclaré dans <queries> : sans ceci, flutter_tts ne trouve aucun
# moteur de synthèse et le Mentor reste muet sur la plupart des téléphones.
# Le greffon ne le déclare pas lui-même (son manifeste est vide).
# Le gabarit de `flutter create` porte déjà un <queries> (PROCESS_TEXT) :
# l'intention s'y ajoute plutôt que d'ouvrir un second bloc.
if ! grep -q 'android.intent.action.TTS_SERVICE' "$MANIFEST"; then
  if grep -q '<queries>' "$MANIFEST"; then
    sed -i.bak 's|<queries>|<queries>\
        <intent>\
            <action android:name="android.intent.action.TTS_SERVICE"/>\
        </intent>|' "$MANIFEST"
  else
    sed -i.bak 's|<application|<queries>\
        <intent>\
            <action android:name="android.intent.action.TTS_SERVICE"/>\
        </intent>\
    </queries>\
    <application|' "$MANIFEST"
  fi
  rm -f "$MANIFEST.bak"
fi

# ── Fin de repos, écran éteint (flutter_local_notifications) ────────────────
#
# Le minuteur de repos programme une notification « Repos terminé » auprès du
# SYSTÈME : écran noir, l'appli est suspendue et ne peut plus rien annoncer.
# Le greffon ne déclare que POST_NOTIFICATIONS et VIBRATE ; une notification
# PROGRAMMÉE demande en plus (son README, version 22) :
#   - ses deux récepteurs, sans quoi l'alarme sonne dans le vide ;
#   - RECEIVE_BOOT_COMPLETED, pour la reprogrammer après un redémarrage ;
#   - SCHEDULE_EXACT_ALARM, pour sonner À L'HEURE : accordée d'office
#     jusqu'à Android 13 ; refusée par défaut à partir d'Android 14, où la
#     fin de repos reste programmée, en alarme inexacte (quelques secondes à
#     quelques minutes de retard plutôt que le silence). Pas USE_EXACT_ALARM :
#     réservée aux réveils et agendas, le Play Store la contrôle.
for permission in RECEIVE_BOOT_COMPLETED SCHEDULE_EXACT_ALARM; do
  if ! grep -q "android.permission.$permission\"" "$MANIFEST"; then
    sed -i.bak "s|<application|<uses-permission android:name=\"android.permission.$permission\"/>\\
    <application|" "$MANIFEST"
    rm -f "$MANIFEST.bak"
  fi
done
if ! grep -q 'ScheduledNotificationReceiver' "$MANIFEST"; then
  sed -i.bak 's|</application>|    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\
            <intent-filter>\
                <action android:name="android.intent.action.BOOT_COMPLETED"/>\
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />\
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\
            </intent-filter>\
        </receiver>\
    </application>|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi

# Le greffon s'appuie sur le DÉSUCRAGE Java (les API de date récentes sur les
# vieux Android) : sans lui, la compilation échoue. Le gabarit de `flutter
# create` porte un `compileOptions {` et aucun bloc `dependencies` ; un
# gabarit qui changerait de forme est REFUSÉ ici plutôt que de produire un
# APK qui ne compile pas plus loin.
GRADLE="android/app/build.gradle.kts"
if ! grep -q 'isCoreLibraryDesugaringEnabled' "$GRADLE"; then
  sed -i.bak 's|compileOptions {|compileOptions {\
        isCoreLibraryDesugaringEnabled = true|' "$GRADLE"
  rm -f "$GRADLE.bak"
  printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n' >> "$GRADLE"
  grep -q 'isCoreLibraryDesugaringEnabled = true' "$GRADLE" || {
    echo "$GRADLE : bloc compileOptions introuvable, désucrage non activé" >&2
    exit 1
  }
fi

# ── Pas de sauvegarde Android ───────────────────────────────────────────────
#
# Par défaut (`allowBackup` absent vaut « true »), Android copie les données de
# l'application vers le compte Google, EN CLAIR pour elle : la base Drift
# (séances, eau), les préférences (réponses de profil — poids, taille, âge —,
# dernier fil du coach). Rien de cela n'a besoin d'une sauvegarde : le serveur
# fait foi et l'application rapatrie tout à la connexion, et les jetons, eux,
# ne se restaurent de toute façon pas (trousseau lié à l'appareil). Garder la
# sauvegarde n'apportait rien et exposait des données de santé. Aucune
# bibliothèque du projet ne déclare l'attribut : la fusion du manifeste ne
# peut pas entrer en conflit (vérifié le 30/09/2026).
if ! grep -q 'android:allowBackup' "$MANIFEST"; then
  sed -i.bak 's|<application|<application android:allowBackup="false"|' "$MANIFEST"
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
  sed -i.bak 's|</manifest>|    <application\
        android:networkSecurityConfig="@xml/network_security_config" />\
</manifest>|' "$DEBUG_MANIFEST"
  rm -f "$DEBUG_MANIFEST.bak"
fi

# ── Santé connectée : Health Connect, en LECTURE seule ──────────────────────
#
# Le greffon `health` (docs/product/sante-connectee.md) ne déclare rien dans
# son manifeste : tout ce que Health Connect exige vit ici.
#  - trois permissions de LECTURE, et aucune d'écriture : Carlys n'écrit rien ;
#  - la visibilité du paquet Health Connect (Android 9 à 13, où c'est une
#    application à installer) et de son intention de justification ;
#  - la JUSTIFICATION des permissions, exigée par Google Play : l'intention
#    ACTION_SHOW_PERMISSIONS_RATIONALE (Android 13 et moins) sur l'activité,
#    VIEW_PERMISSION_USAGE (Android 14+) sur un alias. Les deux ouvrent
#    l'écran « /sante-connectee » (MainActivity, plus bas), qui dit ce que
#    Carlys lit et mène à la politique de confidentialité.
for permission in READ_STEPS READ_WEIGHT READ_BODY_FAT; do
  if ! grep -q "android.permission.health.$permission\"" "$MANIFEST"; then
    sed -i.bak "s|<application|<uses-permission android:name=\"android.permission.health.$permission\"/>\\
    <application|" "$MANIFEST"
    rm -f "$MANIFEST.bak"
  fi
done
# Le <queries> existe ici à coup sûr : le bloc de la synthèse vocale le crée
# quand le gabarit n'en porte pas.
if ! grep -q 'com.google.android.apps.healthdata' "$MANIFEST"; then
  sed -i.bak 's|<queries>|<queries>\
        <package android:name="com.google.android.apps.healthdata"/>\
        <intent>\
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\
        </intent>|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi
# `</activity>` n'apparaît qu'UNE fois : le gabarit n'a qu'une activité, et
# l'alias ci-dessous se ferme sur `</activity-alias>`.
# Le commentaire posé avec le filtre sert de marque : l'action, elle, figure
# déjà dans <queries>.
if ! grep -q 'ShowPermissionsRationale' "$MANIFEST"; then
  sed -i.bak 's|</activity>|    <!-- ShowPermissionsRationale : Health Connect, Android 13 et moins -->\
            <intent-filter>\
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\
            </intent-filter>\
        </activity>|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi
if ! grep -q 'ViewPermissionUsageActivity' "$MANIFEST"; then
  sed -i.bak 's|</application>|    <activity-alias\
            android:name="ViewPermissionUsageActivity"\
            android:exported="true"\
            android:targetActivity=".MainActivity"\
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">\
            <intent-filter>\
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>\
                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>\
            </intent-filter>\
        </activity-alias>\
    </application>|' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi

# L'activité RÉÉCRITE, pas retouchée : le gabarit n'en livre qu'une ligne.
#  - FlutterFragmentActivity : la demande de permissions de Health Connect
#    passe par `registerForActivityResult`, qu'une FlutterActivity n'a pas
#    (README du greffon, « Android 14 ») ;
#  - les deux intentions de justification ouvrent « /sante-connectee » :
#    au lancement (route initiale, que go_router lit), ou par-dessus
#    l'application déjà ouverte (onNewIntent).
ACTIVITY="$(find android/app/src/main/kotlin -name MainActivity.kt | head -n 1)"
if [ -z "$ACTIVITY" ]; then
  echo "MainActivity.kt introuvable sous android/app/src/main/kotlin" >&2
  exit 1
fi
PACKAGE="$(sed -n 's/^package \(.*\)$/\1/p' "$ACTIVITY")"
cat > "$ACTIVITY" <<KOTLIN
package $PACKAGE

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity

// ENGENDRÉ par scripts/android_branding.sh : modifier le script, pas ce
// fichier (android/ n'est pas versionné).
class MainActivity : FlutterFragmentActivity() {
    override fun getInitialRoute(): String? =
        if (isHealthRationale(intent)) HEALTH_ROUTE else super.getInitialRoute()

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (isHealthRationale(intent)) {
            flutterEngine?.navigationChannel?.pushRouteInformation(HEALTH_ROUTE)
        }
    }

    private fun isHealthRationale(intent: Intent?) = intent?.action in RATIONALE_ACTIONS

    private companion object {
        const val HEALTH_ROUTE = "/sante-connectee"
        val RATIONALE_ACTIONS = setOf(
            "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE",
            "android.intent.action.VIEW_PERMISSION_USAGE",
        )
    }
}
KOTLIN

# Health Connect (connect-client 1.2) exige l'API 26 ; le gabarit de Flutter
# 3.44 descend à 24. On prend le plus haut des deux, pour qu'un Flutter qui
# monterait son plancher ne soit jamais rabaissé ici.
if ! grep -q 'minSdk = maxOf(flutter.minSdkVersion, 26)' "$GRADLE"; then
  sed -i.bak 's|minSdk = flutter.minSdkVersion|minSdk = maxOf(flutter.minSdkVersion, 26)|' "$GRADLE"
  rm -f "$GRADLE.bak"
  grep -q 'minSdk = maxOf(flutter.minSdkVersion, 26)' "$GRADLE" || {
    echo "$GRADLE : ligne « minSdk = flutter.minSdkVersion » introuvable" >&2
    exit 1
  }
fi

# iOS, si le dossier a été généré : même nom sous l'icône.
PLIST="ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  sed -i.bak '/<key>CFBundleDisplayName<\/key>/{n;s|<string>.*</string>|<string>Carlys</string>|;}' "$PLIST"
  rm -f "$PLIST.bak"

  # iOS refuse d'ouvrir la caméra ou la photothèque sans MOTIF déclaré :
  # l'application planterait au premier accès, et l'App Store refuse une
  # application qui référence ces accès sans les motiver. Deux motifs, en
  # français, qui disent à quoi sert l'accès et rien de plus :
  #  - la caméra : le scan du code ami ET la photo d'un repas ;
  #  - la photothèque : exigée par l'App Store dès qu'image_picker est là,
  #    même si Carlys passe `requestFullMetadata: false` et que le
  #    sélecteur système n'ouvre alors aucune autorisation.
  #
  # `set_plist_string` REMPLACE la valeur d'une clé déjà présente (un ios/
  # généré avant ce motif garde sinon l'ancien texte) et l'ajoute sinon,
  # avant le DERNIER </dict> — awk, parce que sed ne sait pas dire
  # « dernier » et que Git Bash sous Windows n'a pas python.
  set_plist_string() {
    awk -v key="$1" -v value="$2" '
      { lines[NR] = $0 }
      /<\/dict>/ { last = NR }
      index($0, "<key>" key "</key>") { found = NR }
      END {
        for (i = 1; i <= NR; i++) {
          if (found && i == found + 1) {
            print "\t<string>" value "</string>"
            continue
          }
          if (!found && i == last) {
            print "\t<key>" key "</key>"
            print "\t<string>" value "</string>"
          }
          print lines[i]
        }
      }' "$PLIST" > "$PLIST.tmp" && mv "$PLIST.tmp" "$PLIST"
  }
  set_plist_string NSCameraUsageDescription \
    "L’appareil photo sert à scanner le code ami d’un profil Carlys, le code-barres d’un aliment et à photographier tes repas."
  set_plist_string NSPhotoLibraryUsageDescription \
    "Carlys n’envoie que la photo de repas que tu choisis : le reste de ta photothèque reste sur ton téléphone."

  # ── Apple Santé : LECTURE seule ───────────────────────────────────────────
  # Le motif de LECTURE, et lui seul : sans NSHealthUpdateUsageDescription,
  # iOS refuse toute demande d'écriture — Carlys n'en fait aucune.
  set_plist_string NSHealthShareUsageDescription \
    "Carlys lit tes pas du jour pour l’accueil, et les pesées de ta balance (poids, masse grasse) pour les ajouter à tes mesures. Carlys n’écrit rien dans Santé."

  # La CAPACITÉ HealthKit : le fichier de droits, et le réglage du projet qui
  # le désigne, sur les trois configurations de la cible Runner (les seules
  # à porter `INFOPLIST_FILE = Runner/Info.plist`). Sans elle, HealthKit
  # refuse toute demande. Le profil de provisionnement doit l'inclure aussi :
  # c'est une case de l'App ID chez Apple (docs/product/sante-connectee.md).
  cat > ios/Runner/Runner.entitlements <<'PLIST_XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.developer.healthkit.access</key>
	<array/>
</dict>
</plist>
PLIST_XML
  PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
  if ! grep -q 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' "$PBXPROJ"; then
    sed -i.bak 's|^\([[:space:]]*\)INFOPLIST_FILE = Runner/Info.plist;|\1CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\
\1INFOPLIST_FILE = Runner/Info.plist;|' "$PBXPROJ"
    rm -f "$PBXPROJ.bak"
    [ "$(grep -c 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' "$PBXPROJ")" -eq 3 ] || {
      echo "$PBXPROJ : les trois configurations de Runner n'ont pas reçu leurs droits HealthKit" >&2
      exit 1
    }
  fi
fi

echo "Identité Carlys appliquée : nom, icône, notifications, appareil photo facultatif, synthèse vocale, sans sauvegarde Android, Health Connect en lecture, motifs iOS et HealthKit."
