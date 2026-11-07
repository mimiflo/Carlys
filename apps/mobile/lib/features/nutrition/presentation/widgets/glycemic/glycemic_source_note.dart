import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/glycemic_food.dart';

/// Le pied du tableau : les renvois, le « ± », et la source complète.
class GlycemicSourceNote extends StatelessWidget {
  const GlycemicSourceNote({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.label.copyWith(
      color: AppColors.darkTextSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final mark in GlycemicMark.values)
          Text('${mark.symbol} ${mark.meaning}', style: style),
        Text('± Erreur standard de la moyenne.', style: style),
        Text(
          'Glucose à 103 : moyenne mesurée de la référence, fixée à\u00a0100.',
          style: style,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Source : $glycemicIndexSource Sélection traduite et regroupée '
          'par Carlys.',
          style: style,
        ),
      ],
    );
  }
}
