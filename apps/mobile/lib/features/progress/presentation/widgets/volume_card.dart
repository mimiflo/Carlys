import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../utils/progress_stats.dart';

/// « Volume soulevé » (maquette d'octobre 2026) : le total de la période, la
/// fenêtre analysée, puis une barre par intervalle avec son chiffre et une
/// échelle — tout est dérivé des points réels de l'API.
class VolumeCard extends StatelessWidget {
  const VolumeCard({required this.overview, super.key});

  final ProgressOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    final from = overview.from;
    final to = overview.to;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(AppIcons.volumeLifted, color: AppColors.primaryLight),
              SizedBox(width: AppSpacing.xs),
              AppSectionLabel('Volume soulevé'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text.rich(
            TextSpan(
              text: formatThousands(overview.totalVolumeKg),
              style: AppTypography.display.copyWith(
                color: AppColors.darkTextPrimary,
              ),
              children: [
                TextSpan(
                  text: ' kg',
                  style: AppTypography.title.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (from != null && to != null)
            Text(
              'Du ${formatDayRange(from.toLocal(), to.toLocal())}',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          VolumeBars(points: overview.points, period: overview.period),
        ],
      ),
    );
  }
}

/// Le dégradé violet de l'appli, du haut vers le bas de la barre.
const LinearGradient _barGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.ctaStart, AppColors.ctaEnd],
);

/// Le graphe en barres : échelle à gauche, quadrillage en tirets, le chiffre
/// au-dessus de chaque barre quand il y a la place de le lire.
class VolumeBars extends StatelessWidget {
  const VolumeBars({required this.points, required this.period, super.key});

  final List<ProgressPoint> points;
  final ProgressPeriod period;

  static const double height = 190;

  /// Au-delà, les chiffres au-dessus des barres s'effacent, quelle que soit
  /// la place : l'échelle suffit.
  static const int labelledBarsMax = 7;

  /// La place, en points de TEXTE, que demandent un chiffre au-dessus d'une
  /// barre (« 3 400 ») et un libellé sous elle (« lun. 5 », « 30 sept. »).
  /// En deçà, le chiffre s'efface et les libellés s'espacent : sur 320
  /// points, sept barres et leurs jours se chevauchaient.
  static const double _valueWidth = 36;
  static const double _labelWidth = 52;

  /// La largeur réservée à l'échelle de gauche, en points de texte.
  static const double _axisWidth = 52;

  @override
  Widget build(BuildContext context) {
    final maxVolume = points.fold<double>(
      0,
      (max, point) => point.volumeKg > max ? point.volumeKg : max,
    );
    final step = volumeScaleStep(maxVolume);
    // Une marge au-dessus de la plus haute barre, pour son chiffre.
    final maxY = step * ((maxVolume * 1.15) / step).ceil().clamp(1, 1000);
    final bucket = bucketOf(period);
    final axis = AppTypography.label.copyWith(
      color: AppColors.darkTextSecondary,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final axisWidth = scaler.scale(_axisWidth);

    return Semantics(
      label: volumeBarsSemantics(points, bucket),
      excludeSemantics: true,
      child: RepaintBoundary(
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = points.isEmpty ? 1 : points.length;
              final slot = (constraints.maxWidth - axisWidth) / count;
              final barWidth = slot * 0.6 < 30 ? slot * 0.6 : 30.0;
              final showValues =
                  points.length <= labelledBarsMax &&
                  slot >= scaler.scale(_valueWidth);
              // Un libellé toutes les `labelEvery` barres, compté depuis la
              // DERNIÈRE : le jour le plus récent garde toujours le sien.
              final labelEvery = (scaler.scale(_labelWidth) / slot)
                  .ceil()
                  .clamp(1, count);
              return BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      left: BorderSide(color: AppColors.darkBorder),
                      bottom: BorderSide(color: AppColors.darkBorder),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.darkBorder,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: step,
                        reservedSize: axisWidth,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(formatThousands(value), style: axis),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: scaler.scale(28),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 ||
                              index >= points.length ||
                              (points.length - 1 - index) % labelEvery != 0) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              bucketLabel(points[index].bucketStart, bucket),
                              style: axis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Le chiffre au-dessus de la barre passe par l'infobulle de
                  // fl_chart, affichée en permanence et sans fond.
                  barTouchData: BarTouchData(
                    enabled: false,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.backdropClear,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: AppSpacing.xxs,
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        formatThousands(rod.toY),
                        AppTypography.label.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (final (index, point) in points.indexed)
                      BarChartGroupData(
                        x: index,
                        showingTooltipIndicators: showValues
                            ? const [0]
                            : const [],
                        barRods: [
                          BarChartRodData(
                            toY: point.volumeKg,
                            width: barWidth,
                            gradient: _barGradient,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.xs),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
