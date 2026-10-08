import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../utils/progress_stats.dart';
import 'body_weight_latest.dart';

const double _chartHeight = 150;

/// Courbe du poids corporel (maquette d'octobre 2026) : la dernière mesure
/// en tête, puis la courbe avec son échelle, ses dates et un point par
/// mesure — la plus récente cerclée.
class BodyWeightChart extends StatelessWidget {
  const BodyWeightChart({required this.entries, super.key})
    : assert(
        entries.length >= minimumEntries,
        'une courbe demande au moins deux mesures',
      );

  static const int minimumEntries = 2;

  final List<BodyMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    final values = entries.map((entry) => entry.value);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final (:minY, :maxY, :step) = weightAxis(minValue, maxValue);
    final last = entries.length - 1;
    final scaler = MediaQuery.textScalerOf(context);
    // En texte agrandi, quatre dates ne tiennent plus côte à côte : la
    // première et la dernière suffisent.
    final marks = _marks(last, sparse: scaler.scale(1) > 1.3);
    final axis = AppTypography.label.copyWith(
      color: AppColors.darkTextSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BodyWeightLatest(entry: entries.last),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label:
              'Évolution du poids corporel, de '
              '${formatDecimal(entries.first.value)} à '
              '${formatDecimal(entries.last.value)} kilos '
              'sur ${entries.length} mesures',
          excludeSemantics: true,
          // Isole le rendu du graphique : ses repeints restent locaux.
          child: RepaintBoundary(
            child: SizedBox(
              height: _chartHeight,
              // La courbe SE DESSINE, du plus ancien vers aujourd'hui.
              child: AppRevealSweep(
                // La plus haute graduation débordait en haut, la dernière
                // date à droite : la marge les garde dans la carte.
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.sm,
                    right: AppSpacing.lg,
                  ),
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: last.toDouble(),
                      minY: minY,
                      maxY: maxY,
                      lineTouchData: const LineTouchData(enabled: false),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          bottom: BorderSide(color: AppColors.darkBorder),
                        ),
                      ),
                      gridData: FlGridData(
                        horizontalInterval: step,
                        // Une verticale sous chaque date, et seulement là.
                        verticalInterval: 1,
                        checkToShowVerticalLine: (value) =>
                            marks.contains(value.round()),
                        getDrawingHorizontalLine: _dashed,
                        getDrawingVerticalLine: _dashed,
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: step,
                            reservedSize: scaler.scale(40),
                            getTitlesWidget: (value, meta) => SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(formatDecimal(value), style: axis),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: scaler.scale(26),
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (value != index.toDouble() ||
                                  !marks.contains(index)) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  formatDayMonth(entries[index].measuredAt),
                                  style: axis,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < entries.length; i++)
                              FlSpot(i.toDouble(), entries[i].value),
                          ],
                          color: AppColors.primaryLight,
                          barWidth: 2,
                          dotData: FlDotData(
                            getDotPainter: (spot, _, __, index) =>
                                FlDotCirclePainter(
                                  radius: index == last ? 6 : 3.5,
                                  color: AppColors.primaryLight,
                                  strokeWidth: index == last ? 4 : 0,
                                  strokeColor: AppColors.primaryBadgeBg,
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primaryBadgeBg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static FlLine _dashed(double _) => const FlLine(
    color: AppColors.darkBorder,
    strokeWidth: 1,
    dashArray: [4, 4],
  );

  /// Quatre dates au plus sous la courbe : la première, la dernière et deux
  /// entre elles — ou les deux bouts seulement, [sparse].
  static Set<int> _marks(int last, {required bool sparse}) => sparse
      ? {0, last}
      : {0, (last / 3).round(), (last * 2 / 3).round(), last};
}
