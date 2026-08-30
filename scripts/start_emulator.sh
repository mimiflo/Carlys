#!/usr/bin/env bash
# Démarre un émulateur Android et attend qu'il soit VRAIMENT prêt.
#
# Idempotent : si un appareil Android répond déjà (émulateur lancé, ou
# téléphone branché en USB), le script ne fait rien et rend la main tout de
# suite. C'est ce qui permet de l'accrocher à chaque lancement sans jamais
# rouvrir une seconde fenêtre d'émulateur.
#
# Tout passe par `flutter`, jamais par adb ni par un chemin de SDK deviné :
# c'est le seul outil dont on sait qu'il est dans le PATH, et il se comporte
# pareil sous Windows, macOS et Linux.
#
# Sans set -e : ne JAMAIS empêcher un lancement de démarrer. Au pire on rend
# la main avec un message, et Flutter demandera l'appareil comme avant.
set -uo pipefail

# Préférence d'appareil, surchargeable : CARLYS_AVD=Pixel_7 ./scripts/start_emulator.sh
PREFERRED="${CARLYS_AVD:-pixel_8}"
BOOT_TIMEOUT="${CARLYS_AVD_TIMEOUT:-180}" # secondes

command -v flutter >/dev/null 2>&1 || {
  echo "Flutter introuvable dans le PATH — émulateur non démarré."
  exit 0
}

android_ready() {
  # `devices --machine` donne du JSON ; la clé qui nous intéresse est
  # `targetPlatform` (android-arm64, android-x64…), PAS `platformType` qui
  # n'existe pas. Un émulateur n'y apparaît qu'une fois assez démarré pour
  # accepter une installation — c'est exactement le signal qu'on attend.
  flutter devices --machine 2>/dev/null | grep -q '"targetPlatform": *"android'
}

if android_ready; then
  echo "Appareil Android déjà prêt."
  exit 0
fi

# `flutter emulators` n'accepte PAS --machine : sa sortie est un tableau dont
# les colonnes sont séparées par « • », l'identifiant en premier. On écarte la
# ligne d'en-tête et tout ce qui n'est pas une ligne de tableau.
AVDS="$(flutter emulators 2>/dev/null |
  grep '•' |
  sed 's/[[:space:]]*•.*//; s/^[[:space:]]*//; s/[[:space:]]*$//' |
  grep -viE '^id$')"

if [ -z "$AVDS" ]; then
  echo "Aucun émulateur configuré. En créer un : Android Studio → Device Manager,"
  echo "ou : flutter emulators --create"
  exit 0
fi

# Le préféré s'il existe, sinon le premier venu — mieux vaut un émulateur
# que pas d'émulateur.
AVD="$(printf '%s\n' "$AVDS" | grep -iF "$PREFERRED" | head -1)"
[ -z "$AVD" ] && AVD="$(printf '%s\n' "$AVDS" | head -1)"

echo "Démarrage de l'émulateur « $AVD »…"
flutter emulators --launch "$AVD" >/dev/null 2>&1 &

# Attente ACTIVE de la disponibilité : un émulateur dont la fenêtre est
# apparue n'accepte pas encore d'installation. Sans cette attente, le
# lancement échouerait sur « no devices found » une fois sur deux.
elapsed=0
while [ "$elapsed" -lt "$BOOT_TIMEOUT" ]; do
  if android_ready; then
    echo "Émulateur prêt (${elapsed}s)."
    exit 0
  fi
  sleep 3
  elapsed=$((elapsed + 3))
  [ $((elapsed % 30)) -eq 0 ] && echo "  …toujours en démarrage (${elapsed}s)"
done

echo "L'émulateur n'a pas répondu en ${BOOT_TIMEOUT}s — il finit peut-être de"
echo "démarrer. Relancer suffit en général."
exit 0
