import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../providers/today_metrics.dart';
import 'today_gauge.dart';

/// Une mesure : son libellé, son chiffre face à sa cible, sa jauge, son reste.
class TodayCell extends StatelessWidget {
  const TodayCell({required this.metric, this.onTap, super.key});

  final TodayMetric metric;

  /// Rend la cellule actionnable. Une mesure qu'on peut nourrir ou dont la
  /// cible reste à calculer mérite un geste ; les autres n'en ont pas et ne
  /// doivent surtout pas faire croire le contraire.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = _tint(metric.kind);

    return Semantics(
      label:
          '${metric.label} : ${metric.value} ${metric.target}, '
          '${metric.note}',
      button: onTap != null,
      container: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: _Tappable(
          onTap: onTap,
          child: ColoredBox(
            color: AppColors.darkSurface,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gapRow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(_icon(metric.kind), size: 14, color: tint),
                      const SizedBox(width: AppSpacing.xs - 1),
                      Expanded(
                        child: Text(
                          metric.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.resized(
                                AppTypography.labelMono,
                                9,
                              ).copyWith(
                                letterSpacing: 1.4,
                                color: AppColors.textMuted,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gapTile - 1),
                  // Le chiffre et sa cible se resserrent ENSEMBLE plutôt que
                  // de couper la cible (« / 2 759 k… ») sur un écran étroit
                  // ou en texte agrandi.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          metric.value,
                          style:
                              AppTypography.resized(
                                AppTypography.metricM,
                                17,
                              ).copyWith(
                                letterSpacing: -0.34,
                                color: AppColors.darkTextPrimary,
                              ),
                        ),
                        if (metric.target.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            metric.target,
                            maxLines: 1,
                            style: AppTypography.labelMono.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.gapTile - 1),
                  TodayGauge(ratio: metric.ratio, tint: tint),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    metric.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      fontSize: 11,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(TodayMetricKind kind) => switch (kind) {
    TodayMetricKind.calories => AppIcons.nutrition,
    TodayMetricKind.proteines => AppIcons.protein,
    TodayMetricKind.hydratation => AppIcons.water,
    TodayMetricKind.volume => AppIcons.workout,
    TodayMetricKind.pas => AppIcons.steps,
  };

  /// Le volume est le seul fait d'ENTRAÎNEMENT de la grille : il porte donc
  /// l'orange, les trois autres le violet de la nutrition.
  static Color _tint(TodayMetricKind kind) => kind == TodayMetricKind.volume
      ? AppColors.accent
      : AppColors.primaryLight;
}

/// Enrobage d'interaction posé UNIQUEMENT quand un geste existe : sans lui,
/// une cellule inerte capterait quand même les effets de pression, et
/// promettrait une action qui n'arriverait jamais.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}
