import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import 'award_seal.dart';
import 'dashed_outline.dart';

/// LA PREMIÈRE RÉCOMPENSE, avant qu'elle existe.
///
/// Un compte neuf n'a rien à montrer : il a une porte à ouvrir. La carte
/// montre donc le sceau qu'il va gagner, dessiné mais PAS FRAPPÉ, et le
/// geste exact qui le frappera. C'est la seule action de l'écran, et le seul
/// orange qu'il s'autorise.
///
/// Ce n'est pas un état vide. Un état vide dirait « rien ici » ; celle-ci dit
/// « voilà ce qui vient, et voici par où commencer ».
class FirstAwardCard extends StatelessWidget {
  const FirstAwardCard({
    required this.reward,
    required this.onStart,
    super.key,
  });

  final Reward reward;

  /// Le geste d'amorce. Il ouvre l'Academy : c'est la porte la moins chère
  /// de l'application, celle qui ne demande ni salle ni matériel.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const DashedOutline(
        radius: AppRadius.cardSecondary,
        stroke: AppColors.majestyBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.padCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  // La silhouette est là, sa matière pas encore. Elle se
                  // remplira le jour où elle se gagnera.
                  opacity: 0.75,
                  child: AwardSeal(kind: reward.kind, earned: false),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.label,
                        style: AppTypography.heading.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        reward.story,
                        style: AppTypography.body.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Ouvrir la première leçon',
              onPressed: onStart,
              variant: AppButtonVariant.accent,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
