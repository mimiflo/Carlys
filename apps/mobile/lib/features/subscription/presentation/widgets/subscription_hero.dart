import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Accroche de la maquette 2i : label mono accent, titre display sur deux
/// lignes et paragraphe secondaire, dans la gouttière large du haut d'écran.
class SubscriptionHero extends StatelessWidget {
  const SubscriptionHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gapSection),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionLabel('Carlys Premium', color: AppColors.accent),
          const SizedBox(height: AppSpacing.gapTile),
          Semantics(
            header: true,
            child: Text(
              'Ton coach\nne dort jamais.',
              style: AppTypography.display.copyWith(
                height: 1.08,
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.gapTile),
          Text(
            'Programmation adaptative, macros recalculées chaque jour, '
            'historique illimité.',
            style: AppTypography.body.copyWith(
              fontSize: 14,
              height: 1.5,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
