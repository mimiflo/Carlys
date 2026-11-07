import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/glycemic_food.dart';
import 'glycemic_food_row.dart';

/// L'explication en tête de page : ce que l'IG mesure, ce qu'il ne mesure
/// pas, et les trois niveaux. Courte, parce qu'on vient chercher un chiffre.
class GlycemicIntroCard extends StatelessWidget {
  const GlycemicIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.body.copyWith(
      color: AppColors.darkTextSecondary,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ce que l’IG mesure',
            style: AppTypography.subheading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'De combien un aliment fait monter ta glycémie dans les deux '
            'heures, comparé au glucose pur (IG 100), pour une même quantité '
            'de glucides.',
            style: body,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Il ne tient pas compte de la portion : c’est le rôle de la '
            'charge glycémique. Il varie aussi avec la cuisson, la maturité '
            'et le repas qui l’accompagne.',
            style: body,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('C’est un repère, pas un avis médical.', style: body),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              _Level(GlycemicLevel.low, '≤ 55'),
              _Level(GlycemicLevel.medium, '56 à 69'),
              _Level(GlycemicLevel.high, '≥ 70'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Level extends StatelessWidget {
  const _Level(this.level, this.range);

  final GlycemicLevel level;
  final String range;

  @override
  Widget build(BuildContext context) {
    final label = level.label;
    return Text(
      '${label[0].toUpperCase()}${label.substring(1)} $range',
      style: AppTypography.label.copyWith(color: level.color),
    );
  }
}
