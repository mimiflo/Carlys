#!/usr/bin/env bash
# Tailles de fichiers Flutter — les seuils du tableau de CLAUDE.md.
#
# Pourquoi un script et pas une règle de lint : l'analyseur Dart n'en a pas.
# Mesuré, `max_lines_per_file` dans analysis_options.yaml rend « 'max_lines_
# per_file' isn't a recognized lint rule ». Il n'existe donc AUCUN moyen de
# faire tenir cette règle par l'outillage standard : soit on l'écrit ici,
# soit personne ne la relit jamais.
#
# Le classement se fait par CONVENTION DE CHEMIN, seule information dont
# dispose un script. Un fichier qu'aucun motif ne reconnaît n'est pas
# contrôlé : mieux vaut un filet qui couvre franchement trois catégories
# qu'un filet qui prétend tout couvrir en devinant.
#
# ── Catégories volontairement NON contrôlées, et pourquoi ────────────────
#
# 1. `data/repositories/` (jusqu'à 353 lignes). CLAUDE.md ne lui donne PAS
#    de plafond de fichier : la longueur d'un dépôt suit le nombre de
#    méthodes du contrat qu'il implémente, pas sa complexité. Ce qu'il
#    plafonne, c'est la MÉTHODE (40 lignes) — une mesure que ce script ne
#    sait pas faire, et que la section « Tailles de fichiers » de CLAUDE.md
#    confie à une commande `awk` qu'elle embarque.
#
#    `presentation/controllers/` EST contrôlé, à 250 comme un widget :
#    l'arbitrage de septembre 2026 range le Notifier Riverpod dans la couche
#    présentation, dont il partage le budget. La marge est mince — le plus
#    gros, `coach_controllers.dart`, est à 249 — donc ce seuil mordra tôt.
#    C'est voulu : il n'y a pas de dette à rembourser, seulement une porte
#    à ne pas franchir.
#
# 2. `design_system/scenes/` (jusqu'à 486 lignes). Ce n'est pas de l'écran :
#    c'est un moteur de rendu 3D logiciel — le plus gros fichier n'y déclare
#    aucun widget, seulement de la couleur linéaire, des lumières, un shader
#    et une caméra. Le seuil « Widget Flutter » n'a pas de sens pour lui.
set -euo pipefail

cd "$(dirname "$0")/../apps/mobile"

# Seuils de CLAUDE.md, exprimés en « strictement inférieur à ».
readonly WIDGET_LIMIT=250
readonly CONTROLLER_LIMIT=250
readonly USECASE_LIMIT=200
readonly SERVICE_LIMIT=300

violations=0
widget_count=0
widget_max=0
controller_count=0
controller_max=0
usecase_count=0
usecase_max=0
service_count=0
service_max=0

while IFS= read -r file; do
  case "$file" in
    */presentation/widgets/* | */presentation/screens/* | \
      lib/design_system/components/* | lib/shared/widgets/*)
      kind='Widget Flutter'
      limit=$WIDGET_LIMIT
      ;;
    */presentation/controllers/*)
      kind='Contrôleur'
      limit=$CONTROLLER_LIMIT
      ;;
    */usecases/*)
      kind='Use case'
      limit=$USECASE_LIMIT
      ;;
    */services/*)
      kind='Service'
      limit=$SERVICE_LIMIT
      ;;
    *) continue ;;
  esac

  # `grep -c ''` et non `wc -l` : wc compte les SAUTS de ligne, donc un
  # fichier sans saut final est rapporté une ligne trop court et pourrait
  # franchir le seuil sans être vu. `dart format` impose ce saut quelques
  # étapes plus loin, mais un filet ne doit pas dépendre d'un autre.
  lines=$(grep -c '' "$file")

  case "$kind" in
    'Widget Flutter')
      widget_count=$((widget_count + 1))
      if [ "$lines" -gt "$widget_max" ]; then widget_max=$lines; fi
      ;;
    'Contrôleur')
      controller_count=$((controller_count + 1))
      if [ "$lines" -gt "$controller_max" ]; then controller_max=$lines; fi
      ;;
    'Use case')
      usecase_count=$((usecase_count + 1))
      if [ "$lines" -gt "$usecase_max" ]; then usecase_max=$lines; fi
      ;;
    'Service')
      service_count=$((service_count + 1))
      if [ "$lines" -gt "$service_max" ]; then service_max=$lines; fi
      ;;
  esac

  if [ "$lines" -ge "$limit" ]; then
    if [ "$violations" -eq 0 ]; then
      echo "✗ Seuils de taille dépassés (tableau « Tailles de fichiers »" \
        "de CLAUDE.md)."
      echo "  Découper : extraire un widget, un service ou un use case —" \
        'jamais contourner le seuil.'
      echo ""
    fi
    violations=$((violations + 1))
    printf '  %-13s %4d lignes (limite %d) — apps/mobile/%s\n' \
      "$kind" "$lines" "$limit" "$file"
  fi
# Les fichiers engendrés sont exclus : ce n'est pas nous qui les écrivons,
# et `app_database.g.dart` pèse à lui seul plusieurs milliers de lignes.
done < <(find lib -name '*.dart' ! -name '*.g.dart' | sort)

if [ "$violations" -gt 0 ]; then
  echo ""
  echo "  $violations fichier(s) au-dessus du seuil."
  exit 1
fi

printf 'Widgets : %d fichiers (max %d/%d) · ' \
  "$widget_count" "$widget_max" "$WIDGET_LIMIT"
printf 'contrôleurs : %d (max %d/%d) · ' \
  "$controller_count" "$controller_max" "$CONTROLLER_LIMIT"
printf 'use cases : %d (max %d/%d) · ' \
  "$usecase_count" "$usecase_max" "$USECASE_LIMIT"
printf 'services : %d (max %d/%d).\n' \
  "$service_count" "$service_max" "$SERVICE_LIMIT"
