import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/today_metrics.dart';

/// AUJOURD'HUI : quatre mesures dans UNE surface.
///
/// Les filets en croix naissent d'un espacement d'un point sur un fond clair,
/// pas de bordures dessinées : quatre tuiles bordées chacune donnaient quatre
/// îlots posés sur le fond, là où il n'y a qu'un seul état du jour.
///
/// Chaque cellule dit ce qui est fait, ce qui était visé et ce qu'il reste.
/// La valeur seule ne vaut rien : « 654 kcal » n'est ni bon ni mauvais tant
/// qu'on ignore la cible.
class TodayGrid extends StatelessWidget {
  const TodayGrid({required this.metrics, super.key});

  final List<TodayMetric> metrics;

  /// Épaisseur du filet interne — c'est l'espacement qui le dessine.
  static const double _rule = 1;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.listRow),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(AppRadius.listRow),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Padding(
          // Deux points de marge : la bordure extérieure ne doit pas se
          // confondre avec les filets internes.
          padding: const EdgeInsets.all(2),
          child: ColoredBox(
            color: AppColors.gridRule,
            child: Column(
              children: [
                for (var row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: _rule),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: TodayCell(metric: metrics[row * 2])),
                        const SizedBox(width: _rule),
                        Expanded(
                          child: TodayCell(metric: metrics[row * 2 + 1]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une mesure : son libellé, son chiffre face à sa cible, sa jauge, son reste.
class TodayCell extends StatelessWidget {
  const TodayCell({required this.metric, super.key});

  final TodayMetric metric;

  static const double gaugeHeight = 2;

  @override
  Widget build(BuildContext context) {
    final tint = _tint(metric.kind);

    return Semantics(
      label: '${metric.label} : ${metric.value} ${metric.target}, '
          '${metric.note}',
      child: ExcludeSemantics(
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
                        style: AppTypography.labelMono.copyWith(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gapTile - 1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      metric.value,
                      style: AppTypography.metricM.copyWith(
                        fontSize: 17,
                        letterSpacing: -0.34,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    if (metric.target.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Flexible(
                        child: Text(
                          metric.target,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMono
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.gapTile - 1),
                _Gauge(ratio: metric.ratio, tint: tint),
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
    );
  }

  static IconData _icon(TodayMetricKind kind) => switch (kind) {
        TodayMetricKind.calories => AppIcons.nutrition,
        TodayMetricKind.proteines => AppIcons.protein,
        TodayMetricKind.hydratation => AppIcons.water,
        TodayMetricKind.volume => AppIcons.workout,
      };

  /// Le volume est le seul fait d'ENTRAÎNEMENT de la grille : il porte donc
  /// l'orange, les trois autres le violet de la nutrition.
  static Color _tint(TodayMetricKind kind) => kind == TodayMetricKind.volume
      ? AppColors.accent
      : AppColors.primaryLight;
}

/// La jauge d'une cellule. Sans cible connue, elle passe en tirets : une
/// piste vide se lirait comme un échec là où il n'y a pas d'objectif.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.ratio, required this.tint});

  final double? ratio;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final value = ratio;
    if (value == null) {
      return const SizedBox(
        height: TodayCell.gaugeHeight,
        child: CustomPaint(painter: _PendingTrack(), size: Size.infinite),
      );
    }

    return ClipRRect(
      borderRadius: AppRadius.fullAll,
      child: SizedBox(
        height: TodayCell.gaugeHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.gaugeTrack),
          child: Align(
            alignment: Alignment.centerLeft,
            // Jamais tout à fait zéro : une largeur nulle libère la
            // contrainte, et l'enfant se peindrait à sa taille naturelle.
            widthFactor: value.clamp(0.001, 1),
            child: ColoredBox(color: tint, child: const SizedBox.expand()),
          ),
        ),
      ),
    );
  }
}

class _PendingTrack extends CustomPainter {
  const _PendingTrack();

  static const double _dash = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.pendingTrack;
    for (var x = 0.0; x < size.width; x += _dash * 2) {
      final width = (size.width - x).clamp(0.0, _dash);
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_PendingTrack oldDelegate) => false;
}
