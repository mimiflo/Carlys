import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/reward.dart';
import 'dashed_outline.dart';

/// CE QUI VIENT : une invitation, jamais un manque.
///
/// Le pendant des récompenses gagnées (`award_cards.dart`).
///
/// La bordure en tirets et le fond en retrait la font lire comme « pas
/// encore » sans jamais paraître désactivée. Pas de jauge, pas de compteur :
/// une chose à faire, pas une barre à remplir.
class UpcomingAwardRow extends StatelessWidget {
  const UpcomingAwardRow({required this.reward, super.key});

  final Reward reward;

  static const double _dotSize = 30;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const DashedOutline(radius: AppRadius.listRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.gapRow,
        ),
        child: Row(
          children: [
            Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.majestyBorder),
              ),
              child: const Icon(
                AppIcons.bookmark,
                size: 16,
                color: AppColors.primaryLight,
              ),
            ),
            const SizedBox(width: AppSpacing.gapRow),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.label,
                    style: AppTypography.subheading.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
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
      ),
    );
  }
}
