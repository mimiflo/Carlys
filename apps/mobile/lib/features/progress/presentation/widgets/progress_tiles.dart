import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../utils/progress_stats.dart';

/// Les deux tuiles sous le volume (maquette d'octobre 2026) : le nombre de
/// séances de la période, puis leur durée cumulée et le nombre de séries.
class ProgressTiles extends StatelessWidget {
  const ProgressTiles({required this.overview, super.key});

  final ProgressOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    final seances = _ProgressTile(
      icon: AppIcons.equipmentDumbbell,
      label: 'Séances',
      value: formatThousands(overview.sessionsCount),
      caption: periodCaption(overview.period),
    );
    final duree = _ProgressTile(
      icon: AppIcons.time,
      label: 'Durée',
      value: formatDurationShort(overview.totalDurationSeconds),
      caption: '${formatThousands(overview.setsCount)} séries',
    );
    // En texte agrandi, les tuiles s'EMPILENT sur toute la largeur : côte à
    // côte, chacune ne laissait au texte qu'une soixantaine de points, et
    // « SÉANCES » se coupait en son milieu sur 320 points.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          seances,
          const SizedBox(height: AppSpacing.gapTile),
          duree,
        ],
      );
    }
    // Côte à côte, les deux tuiles ont la même structure : leurs hauteurs
    // se répondent.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: seances),
          const SizedBox(width: AppSpacing.gapTile),
          Expanded(child: duree),
        ],
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;

  static const double _iconSize = 30;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(label),
        const SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: AppTypography.pageTitle.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        Text(
          caption,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
    return Semantics(
      label: '$label : $value, $caption',
      excludeSemantics: true,
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: _iconSize, color: AppColors.primaryLight),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}
