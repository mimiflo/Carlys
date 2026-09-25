#!/usr/bin/env bash
# Applique l'identité Carlys au dossier android/ GÉNÉRÉ par flutter create :
# nom affiché (« Carlys »), icône de lanceur (le sceau de la marque, déclinée
# dans apps/mobile/launcher/), permission de notification Android 13+,
# appareil photo FACULTATIF ; et, côté ios/ s'il existe, le nom et les motifs
# d'accès à l'appareil photo et aux photos.
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
    "L’appareil photo sert à scanner le code ami d’un profil Carlys et à photographier tes repas."
  set_plist_string NSPhotoLibraryUsageDescription \
    "Carlys n’envoie que la photo de repas que tu choisis : le reste de ta photothèque reste sur ton téléphone."
fi

echo "Identité Carlys appliquée : nom, icône, notifications, appareil photo facultatif, motifs iOS."
