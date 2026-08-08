import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../utils/progress_stats.dart';

/// Grille de deux tuiles sous la carte de volume.
///
/// La seconde tuile montre l'assiduité hebdomadaire quand les points la
/// rendent calculable ; sinon elle bascule sur la durée réellement
/// enregistrée plutôt que d'afficher un pourcentage inventé.
class ProgressTiles extends StatelessWidget {
  const ProgressTiles({required this.overview, super.key});

  final ProgressOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    final attendance = weeklyAttendance(overview.points, overview.period);

    // Les deux tuiles ont la même structure (label, valeur, sous-ligne sur
    // une ligne) : leurs hauteurs se répondent sans contrainte explicite.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ProgressTile(
            label: 'Séances',
            value: formatThousands(overview.sessionsCount),
            caption: periodCaption(overview.period),
          ),
        ),
        const SizedBox(width: AppSpacing.gapTile),
        Expanded(
          child: attendance == null
              ? _ProgressTile(
                  label: 'Durée',
                  value: formatDurationShort(overview.totalDurationSeconds),
                  caption: '${formatThousands(overview.setsCount)} séries',
                )
              : _ProgressTile(
                  label: 'Assiduité',
                  value: formatThousands(attendance.percent),
                  unit: '%',
                  caption: 'série de ${formatThousands(attendance.streak)}',
                ),
        ),
      ],
    );
  }
}

/// Tuile : label mono, valeur mono, sous-ligne descriptive en primaryLight.
class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.label,
    required this.value,
    required this.caption,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : $value${unit ?? ''}, $caption',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.listRowAll,
          border:
              Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMono.copyWith(
                fontSize: 9,
                color: AppColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: 7),
            Text.rich(
              TextSpan(
                text: value,
                style: AppTypography.metricM.copyWith(
                  fontSize: 22,
                  letterSpacing: -0.66,
                  color: AppColors.darkTextPrimary,
                ),
                children: [
                  if (unit != null)
                    TextSpan(
                      text: unit,
                      style: AppTypography.metricS.copyWith(
                        fontSize: 13,
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 7),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                fontSize: 11,
                height: 1,
                color: AppColors.primaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
