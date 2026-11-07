import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/glycemic_food.dart';
import '../../../domain/glycemic_selection.dart';

/// Les familles, en pastilles qui défilent de côté (« Tous » d'abord), puis
/// l'ordre de la liste.
class GlycemicFilters extends StatelessWidget {
  const GlycemicFilters({
    required this.category,
    required this.onCategory,
    required this.sort,
    required this.onSort,
    super.key,
  });

  final GlycemicCategory? category;
  final ValueChanged<GlycemicCategory?> onCategory;
  final GlycemicSort sort;
  final ValueChanged<GlycemicSort> onSort;

  @override
  Widget build(BuildContext context) {
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1;
    final label = Text(
      'Trier',
      style: AppTypography.label.copyWith(color: AppColors.darkTextSecondary),
    );
    final pills = AppChoicePills<GlycemicSort>(
      choices: const [
        AppChoice(
          GlycemicSort.byCategory,
          'Familles',
          semanticLabel: 'Par famille',
        ),
        AppChoice(
          GlycemicSort.ascending,
          'IG ↑',
          semanticLabel: 'IG croissant',
        ),
        AppChoice(
          GlycemicSort.descending,
          'IG ↓',
          semanticLabel: 'IG décroissant',
        ),
      ],
      selected: sort,
      onSelected: onSort,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Neuf pastilles sur une rangée qui défile : en `Wrap`, elles
        // prendraient trois lignes avant le premier aliment. Sans rognure :
        // la rangée court jusqu'au bord de l'écran au lieu d'être coupée
        // net à la marge, ce qui dit qu'elle défile.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final choice in <GlycemicCategory?>[
                null,
                ...GlycemicCategory.values,
              ]) ...[
                AppPill(
                  label: choice?.label ?? 'Tous',
                  selected: choice == category,
                  selectedTone: AppPillTone.primary,
                  onTap: () => onCategory(choice),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        // Texte agrandi, « Trier » passe AU-DESSUS des pastilles : à côté,
        // il restait seul au milieu de pastilles repliées sur deux lignes.
        if (enlarged)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: AppSpacing.xxs),
              pills,
            ],
          )
        else
          Row(
            children: [
              label,
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: pills),
            ],
          ),
      ],
    );
  }
}
