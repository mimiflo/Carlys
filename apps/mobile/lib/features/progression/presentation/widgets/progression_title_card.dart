import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';

/// Le titre atteint, les points, et le chemin vers le suivant.
///
/// Le total est affiché en clair : un score qu'on ne peut pas lire ne peut
/// pas être compris, et Carlys explique toujours le pourquoi.
class ProgressionTitleCard extends StatelessWidget {
  const ProgressionTitleCard({required this.profile, super.key});

  final ProgressionProfile profile;

  @override
  Widget build(BuildContext context) {
    final next = profile.title.next;
    final remaining = profile.pointsToNextTitle;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionLabel('Ton titre'),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  profile.title.label,
                  style: AppTypography.display
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
              ),
              Text(
                '${profile.points}',
                style: AppTypography.metricL
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                '/ $maxTotal',
                style: AppTypography.labelMono
                    .copyWith(color: AppColors.darkTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: profile.progressToNextTitle,
              minHeight: 6,
              backgroundColor: AppColors.gaugeTrack,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primaryFlash),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            next == null || remaining == null
                ? 'Dernier titre atteint. Le reste, c’est la suite de ton '
                    'histoire.'
                : 'Encore $remaining points avant ${next.label}.',
            style: AppTypography.label
                .copyWith(color: AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}
