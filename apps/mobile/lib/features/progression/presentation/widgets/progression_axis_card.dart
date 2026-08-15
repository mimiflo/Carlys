import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';

/// Un axe : sa valeur, sa jauge, ses points, et la phrase qui l'explique.
///
/// L'axe en attente n'affiche NI jauge NI points. Une jauge vide et un « 0 »
/// se lisent comme un échec, alors qu'il n'y a simplement pas encore de
/// données ; la phrase dit à la place comment l'ouvrir.
class ProgressionAxisCard extends StatelessWidget {
  const ProgressionAxisCard({required this.axis, super.key});

  final ProgressionAxis axis;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  axis.value.label.toUpperCase(),
                  style: AppTypography.labelMono.copyWith(
                    color: axis.known
                        ? AppColors.primaryLight
                        : AppColors.darkTextTertiary,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              if (axis.known)
                Text(
                  '${axis.points}',
                  style: AppTypography.metricS
                      .copyWith(color: AppColors.darkTextPrimary),
                )
              else
                Text(
                  'En attente',
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextTertiary),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (axis.known) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: axis.ratio,
                minHeight: 4,
                backgroundColor: AppColors.gaugeTrack,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryFlash,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            axis.reason,
            style:
                AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}
