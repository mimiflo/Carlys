import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';
import 'progression_gauge.dart';

/// LES CINQ AXES, dans UNE carte.
///
/// Cinq cartes empilées donnaient cinq objets à comparer ; une carte à cinq
/// lignes donne un profil qui se lit d'un seul regard. Les axes ne sont pas
/// cinq mesures indépendantes, ils sont les cinq faces d'une même pratique :
/// la mise en page doit le dire.
class AxesCard extends StatelessWidget {
  const AxesCard({required this.axes, super.key});

  final List<ProgressionAxis> axes;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.cardSecondary),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.padCard),
        child: Column(
          children: [
            for (final (index, axis) in axes.indexed) ...[
              if (index > 0) ...[
                const SizedBox(height: AppSpacing.gapRow),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.darkBorder,
                ),
                const SizedBox(height: AppSpacing.gapRow),
              ],
              AxisRow(axis: axis),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un axe : son nom, sa mesure, le fait qui la justifie, sa jauge.
///
/// Un axe sans fait n'affiche PAS un zéro. Il dit « en attente » et explique
/// comment l'ouvrir : un axe vide est une porte, pas un échec.
class AxisRow extends StatelessWidget {
  const AxisRow({required this.axis, super.key});

  final ProgressionAxis axis;

  /// Hauteur de jauge d'axe. Plus fine que celle de la carte de titre : cinq
  /// jauges de même épaisseur que le titre lui voleraient sa place.
  static const double gaugeHeight = 5;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: axis.known
          ? '${axis.value.label} : ${axis.points} points sur $maxAxisPoints'
          : '${axis.value.label} : en attente',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    axis.value.label,
                    style: AppTypography.subheading.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (axis.known)
                  Text(
                    '${axis.points}',
                    style: AppTypography.metricS.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  )
                else
                  Text(
                    'EN ATTENTE',
                    style: AppTypography.labelMono.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              axis.reason,
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.gapTile),
            ProgressionGauge(
              value: axis.ratio,
              height: gaugeHeight,
              // Plein, jamais dégradé : le dégradé est réservé à la carte de
              // titre, sinon plus rien ne hiérarchise l'écran.
              fill: axis.known ? AppColors.axisFill : null,
            ),
          ],
        ),
      ),
    );
  }
}
