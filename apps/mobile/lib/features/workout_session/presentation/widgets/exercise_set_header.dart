import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'exercise_set_row.dart';

/// L'en-tête des colonnes d'un tableau de séries ([ExerciseSetRow]) :
/// « SÉRIE », puis les deux valeurs que l'appelant nomme (« KG » / « REPS »
/// en séance, « CHARGE » / « RÉPÉTITIONS » au bilan, « DURÉE » /
/// « DISTANCE » pour un mouvement chronométré). Muet pour les lecteurs
/// d'écran : chaque ligne dit déjà ses valeurs.
class ExerciseSetHeader extends StatelessWidget {
  const ExerciseSetHeader({
    required this.first,
    required this.second,
    super.key,
  });

  final String first;
  final String second;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.labelMono.copyWith(
      color: AppColors.darkTextSecondary,
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: ExerciseSetColumns.rank,
              child: Text('SÉRIE', textAlign: TextAlign.center, style: style),
            ),
            Expanded(child: Text(first, style: style)),
            Expanded(child: Text(second, style: style)),
            const SizedBox(width: ExerciseSetColumns.status),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
