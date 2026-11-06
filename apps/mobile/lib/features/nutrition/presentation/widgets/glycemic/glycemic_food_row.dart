import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/glycemic_food.dart';

/// La couleur d'un niveau : les tons sémantiques du design system, vert,
/// orange, rouge. Elle n'est jamais seule : le mot (« bas ») la double, pour
/// qui ne distingue pas les couleurs.
extension GlycemicLevelColor on GlycemicLevel {
  Color get color => switch (this) {
    GlycemicLevel.low => AppColors.success,
    GlycemicLevel.medium => AppColors.warning,
    GlycemicLevel.high => AppColors.danger,
  };
}

/// Une ligne du tableau : le nom (et son renvoi), l'erreur standard en
/// petit, l'IG et son niveau à droite. Le lecteur d'écran la lit d'un trait :
/// « Pomme crue, IG 36, bas. »
class GlycemicFoodRow extends StatelessWidget {
  const GlycemicFoodRow({
    required this.food,
    this.showCategory = false,
    super.key,
  });

  final GlycemicFood food;

  /// Dans une liste triée par IG, les familles se mêlent : la ligne dit la
  /// sienne.
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final mark = food.mark;
    final sem = '± ${food.sem}';
    return Semantics(
      label: food.spoken,
      excludeSemantics: true,
      child: AppListRow(
        title: mark == null ? food.name : '${food.name} ${mark.symbol}',
        subtitle: showCategory ? '${food.category.label} · $sem' : sem,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${food.gi}',
              style: AppTypography.metricS.copyWith(color: food.level.color),
            ),
            Text(
              food.level.label.toUpperCase(),
              style: AppTypography.labelMono.copyWith(color: food.level.color),
            ),
          ],
        ),
      ),
    );
  }
}
