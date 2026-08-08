import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

/// Hauteur du tracé (géométrie du graphe, comme la carte de volume).
const double _chartHeight = 104;

/// Carte d'évolution du poids : dernière mesure en grand, puis la courbe.
class BodyWeightChart extends StatelessWidget {
  const BodyWeightChart({required this.entries, super.key});

  /// Du plus ancien au plus récent, au moins une mesure.
  final List<BodyMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    final values = entries.map((entry) => entry.value);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final latest = entries.last;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardMainAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionLabel(
            'Dernière mesure',
            color: AppColors.darkTextTertiary,
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: formatDecimal(latest.value),
              style: AppTypography.metricL.copyWith(
                fontSize: 30,
                letterSpacing: -1.2,
                color: AppColors.darkTextPrimary,
              ),
              children: [
                TextSpan(
                  text: ' kg',
                  style: AppTypography.metricS.copyWith(
                    fontSize: 15,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: 'Évolution du poids corporel',
            // Isole le rendu du graphique : ses repeints restent locaux.
            child: RepaintBoundary(
              child: SizedBox(
                height: _chartHeight,
                child: LineChart(
                  LineChartData(
                    minY: minValue - 1,
                    maxY: maxValue + 1,
                    lineTouchData: const LineTouchData(enabled: false),
                    titlesData: const FlTitlesData(show: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < entries.length; i++)
                            FlSpot(i.toDouble(), entries[i].value),
                        ],
                        isCurved: true,
                        color: AppColors.primaryLight,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primaryCardSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in _axisLabels())
                Text(
                  label,
                  style: AppTypography.labelMono.copyWith(
                    fontSize: 9,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Repères de la courbe : première, médiane et dernière mesure réelles.
  List<String> _axisLabels() {
    final indexes = <int>{0, entries.length ~/ 2, entries.length - 1}.toList()
      ..sort();
    return [
      for (final index in indexes)
        formatShortDateMono(entries[index].measuredAt.toLocal()),
    ];
  }
}
