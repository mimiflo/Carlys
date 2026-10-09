import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// « À retenir » (maquette Academy d'octobre 2026) : un encart violet, la
/// cible, et trois idées au plus — ce qui reste quand le corps de la leçon
/// est oublié.
class LessonKeyPoints extends StatelessWidget {
  const LessonKeyPoints({required this.points, super.key});

  final List<String> points;

  static const double _iconSize = 28;
  static const double _bullet = 6;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryCardSoft,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.primaryLightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            AppIcons.objective,
            size: _iconSize,
            color: AppColors.primaryLight,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionLabel('À retenir'),
                const SizedBox(height: AppSpacing.xs),
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: _bullet,
                          height: _bullet,
                          margin: const EdgeInsets.only(
                            top: AppSpacing.xs,
                            right: AppSpacing.sm,
                          ),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            point,
                            style: AppTypography.body.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
