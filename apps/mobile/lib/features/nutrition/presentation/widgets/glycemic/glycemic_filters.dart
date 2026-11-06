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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Neuf pastilles sur une rangée qui défile : en `Wrap`, elles
        // prendraient trois lignes avant le premier aliment.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
        Row(
          children: [
            Text(
              'Trier',
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: AppChoicePills<GlycemicSort>(
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
              ),
            ),
          ],
        ),
      ],
    );
  }
}
