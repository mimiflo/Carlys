#!/usr/bin/env bash
# Vérification complète du projet Flutter : à exécuter avant tout commit.
#
# Reproduit EXACTEMENT `.github/workflows/mobile-ci.yml`, dans le même ordre.
# C'est le point : `flutter analyze && flutter test` — longtemps la consigne —
# laisse passer ce que la CI refuse. `dart format --set-exit-if-changed` a fait
# tomber une CI verte en local ; cette liste ne doit donc pas diverger.
#
# « EXACTEMENT » se relit bloc `run:` par bloc `run:` : dépendances, génération
# de code, formatage, analyse, tests — les cinq commandes sont identiques au
# caractère près. `--enforce-lockfile` a longtemps manqué ici, sous couvert de
# « seule différence assumée » : une différence assumée reste un filet troué.
# Mesuré sur un paquet au lock désynchronisé : la commande de la CI rend 65
# (« Unable to satisfy `pubspec.yaml` using `pubspec.lock` ») là où un `pub get`
# nu rend 0 EN RÉÉCRIVANT LE LOCK EN SILENCE. Le développeur voyait donc un vert
# local complet, ne commitait pas le lock réécrit, et poussait un job rouge.
# Mettre le lock à jour reste possible — c'est `flutter pub get` sans l'option,
# suivi du commit du lock, ce que dit le message d'échec ci-dessous.
#
# Le seul écart restant avec la CI est le SDK lui-même : l'avertissement de
# version ci-dessous le couvre.
#
# Deux blocs ne font pas partie des cinq commandes de la CI : les tailles de
# fichiers et la couverture des polices. Ce n'est pas une divergence au sens
# ci-dessus — les cinq commandes restent identiques, contiguës et dans le même
# ordre juste après ; ce sont des AJOUTS qui vont dans le sens sûr, et que la
# CI exécute désormais elle aussi, comme étapes distinctes.
#
# Ils sont en tête parce qu'ils coûtent quelques millisecondes et n'ont
# aucune raison de faire attendre derrière deux minutes de tests. Le premier
# est écrit en shell parce que l'analyseur Dart n'a pas de règle de longueur
# de fichier (`max_lines_per_file` rend « isn't a recognized lint rule ») ;
# le second en Python, parce qu'il lit une table binaire de police.
#
# Note : `dart format` et la règle de lint `require_trailing_commas` peuvent se
# contredire sur un appel qui tient de justesse sur deux lignes. La forme qui
# satisfait les deux est l'appel ÉCLATÉ, un argument par ligne, virgule finale
# comprise — le formateur la conserve alors telle quelle.
set -euo pipefail

# Retenu AVANT le `cd` : `$0` est souvent relatif au répertoire d'appel, et
# ne désignerait plus rien une fois qu'on a changé de dossier.
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPTS_DIR/../apps/mobile"

echo "── Version Flutter ─────────────────────────────────────────────────"
# La CI installe la version épinglée dans apps/mobile/.flutter-version
# (source unique, lue aussi par mobile-ci.yml, mobile-recette.yml et mobile-production.yml). Un écart
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

echo "── Tailles de fichiers ─────────────────────────────────────────────"
"$SCRIPTS_DIR/check_mobile_file_sizes.sh"

echo "── Banque d'icônes ─────────────────────────────────────────────────"
# `app_icons.dart` interdit `Icons.*` dans les écrans depuis sa première
# ligne ; rien ne le vérifiait, et 106 références l'avaient contourné.
"$SCRIPTS_DIR/check_mobile_icons.sh"

echo "── Couverture des polices ──────────────────────────────────────────"
# Les neuf TTF embarquées sont SOUS-ENSEMBLÉES : Flutter ne le fait pas pour
# les polices de texte, et les versions complètes emportaient 2,99 Mo dans
# l'APK. Un glyphe perdu ne donne pas un carré vide — l'application retombe
# sur la fonte système — donc rien ne le signale à la relecture. Le contrôle
# lit la table `cmap` à la main, sans dépendance à installer.
python3 "$SCRIPTS_DIR/check_mobile_fonts.py"

echo "── Dépendances ─────────────────────────────────────────────────────"
# Le message de pub est exact mais muet sur la suite : ici, la suite est de
# COMMITER le lock, sans quoi la CI retombera sur le même 65.
#
# Le conseil ne vaut QUE pour le 65 (« Unable to satisfy `pubspec.yaml` using
# `pubspec.lock` »). `pub get` échoue aussi pour de tout autres raisons —
# mesuré sur un pubspec.yaml malformé : code 1, « Unexpected child "rxdart"
# found under "flutter" ». Envoyer alors le développeur relancer `pub get` et
# committer le lock, c'est le lancer sur une piste fausse pendant que la vraie
# cause est déjà à l'écran. On conditionne donc le message au code rendu.
flutter pub get --enforce-lockfile || {
  CODE=$?
  echo ""
  if [ "$CODE" -eq 65 ]; then
    echo "✗ pubspec.lock ne satisfait plus pubspec.yaml — la CI (mobile-ci.yml)"
    echo "  échouera de la même façon, avec ce même code $CODE."
    echo "  Résoudre, RELIRE le résultat, puis committer le lock :"
    echo "      (cd apps/mobile && flutter pub get)"
    echo "      git add apps/mobile/pubspec.lock"
  else
    echo "✗ flutter pub get a échoué (code $CODE), voir la sortie ci-dessus."
  fi
  exit "$CODE"
}

echo "── Génération de code (Drift) ──────────────────────────────────────"
dart run build_runner build

echo "── Formatage ───────────────────────────────────────────────────────"
# Les fichiers générés sont exclus : ce n'est pas nous qui les écrivons.
dart format --output=none --set-exit-if-changed \
  $(find lib test -name '*.dart' ! -name '*.g.dart')

echo "── Analyse statique ────────────────────────────────────────────────"
flutter analyze

echo "── Tests ───────────────────────────────────────────────────────────"
# `TZ=Europe/Paris` recopie le bloc `run:` de la CI, et pour la même raison :
# sous un fuseau sans changement d'heure — UTC sur les runners, et tout poste
# réglé ailleurs qu'en Europe — les gardes de calendrier du dépôt rendent le
# même résultat avec le calcul fautif et avec le calcul correct. Mesuré en
# réintroduisant le bug d'origine de `dayOfYearIndex` : trois tests verts sous
# UTC, deux rouges sous Europe/Paris. Le forcer ici rend la vérification locale
# indépendante du réglage de la machine, ce qui est bien le but du script.
TZ=Europe/Paris flutter test

echo ""
echo "Toutes les vérifications Flutter sont passées."
