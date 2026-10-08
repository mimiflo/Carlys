import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

/// « 78,4 kg · Dernière mesure · 21 sept. » (maquette d'octobre 2026) : la
/// valeur en grand, sa date à côté.
class BodyWeightLatest extends StatelessWidget {
  const BodyWeightLatest({required this.entry, super.key});

  final BodyMetricEntry entry;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AppSpacing.sm,
      children: [
        Text(
          '${formatDecimal(entry.value)} kg',
          style: AppTypography.pageTitle.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
          child: Text(
            'Dernière mesure · ${formatDayMonth(entry.measuredAt)}',
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Avec un seul point, un graphique ne trace rien : la carte affichait un
/// rectangle vide de 104 points sous un balayage qui n'animait aucun tracé,
/// et une date orpheline. Après le geste que l'écran vient d'inviter, on
/// reçoit un fait et une promesse tenue, pas un grand vide.
class BodyWeightFirstMeasure extends StatelessWidget {
  const BodyWeightFirstMeasure({required this.entry, super.key});

  final BodyMetricEntry entry;

  /// Ce que la carte annonce : une mesure de plus et la courbe apparaît.
  static const String note = 'Une mesure de plus et la courbe apparaît.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BodyWeightLatest(entry: entry),
        const SizedBox(height: AppSpacing.md),
        Text(
          note,
          style: AppTypography.label.copyWith(color: AppColors.primaryLight),
        ),
      ],
    );
  }
}
