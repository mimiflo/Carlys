#!/usr/bin/env bash
# Aucun `Icons.` hors du design system.
#
# `app_icons.dart` le dit depuis toujours, en tête de fichier : « Les écrans
# référencent ces noms métier, jamais Icons.* directement : changer de banque
# d'icônes ne touche alors qu'à ce fichier. » La règle était écrite, elle
# n'était pas TENUE — 106 références directes dans 46 fichiers au
# 22 septembre 2026, soit plus que les 89 noms métier déclarés.
#
# Pourquoi un script et pas une règle de lint : l'analyseur Dart ne sait pas
# interdire un identifiant précis dans un sous-arbre précis. Il n'existe donc
# aucun moyen standard de faire tenir cette règle-là.
#
# Ce que la règle protège, concrètement :
#  - **un seul endroit à changer** si la banque d'icônes change ;
#  - **un nom qui dit le SENS** — `AppIcons.restDay` se relit, pas
#    `Icons.bedtime_outlined` ; et deux écrans qui parlent du même état
#    finissent par le montrer pareil, parce qu'ils appellent le même nom ;
#  - **la fin des variantes accidentelles** : `Icons.add` et
#    `Icons.add_rounded` coexistaient dans l'application, le plus et le moins
#    des incrémenteurs n'étant pas ceux du reste des écrans.
set -euo pipefail

cd "$(dirname "$0")/../apps/mobile"

# `lib/design_system/` est le SEUL endroit qui a le droit de nommer la banque
# d'icônes — c'est la définition même de ce qu'est un design system ici.
fautes=$(grep -rnoE '\bIcons\.[a-zA-Z0-9_]+' lib --include='*.dart' \
  --exclude-dir=design_system || true)

if [ -n "$fautes" ]; then
  echo "✗ Des écrans nomment la banque d'icônes directement."
  echo
  echo "$fautes" | sed 's/^/  /'
  echo
  echo "  Déclare un nom MÉTIER dans lib/design_system/icons/app_icons.dart"
  echo "  (celui que l'écran veut dire, pas celui du glyphe), puis appelle"
  echo "  AppIcons.<ce nom>. Si le nom existe déjà, réutilise-le."
  exit 1
fi

echo "Aucun écran ne nomme la banque d'icônes : tout passe par AppIcons."
