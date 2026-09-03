import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import 'body_weight_latest.dart';

/// Hauteur du tracé (géométrie du graphe, comme la carte de volume).
const double _chartHeight = 104;

/// Carte d'évolution du poids : dernière mesure en grand, puis la courbe.
class BodyWeightChart extends StatelessWidget {
  const BodyWeightChart({required this.entries, super.key})
      : assert(
          entries.length >= minimumEntries,
          'une courbe demande au moins deux mesures',
        );

  /// Une courbe se trace entre deux points : en dessous, l'appelant montre
  /// la mesure seule ([BodyWeightFirstMeasure]).
  static const int minimumEntries = 2;

  /// Du plus ancien au plus récent, au moins [minimumEntries] mesures.
  final List<BodyMetricEntry> entries;

  @override
  Widget build(BuildContext context) {
    final values = entries.map((entry) => entry.value);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);

    return BodyWeightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyWeightLatest(entry: entries.last),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: 'Évolution du poids corporel',
            // Isole le rendu du graphique : ses repeints restent locaux.
            child: RepaintBoundary(
              child: SizedBox(
                height: _chartHeight,
                // La courbe SE DESSINE, du plus ancien vers aujourd'hui :
                // c'est le sens du temps, et une courbe déjà tracée à
                // l'arrivée ne raconte pas le trajet.
                child: AppRevealSweep(
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
                          // ROSE, à dessein : tout l'écran vit en violet et
                          // orange, la courbe est LA donnée — le magenta la
                          // détache de son décor d'un seul coup d'œil.
                          color: AppColors.magenta,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.magentaCardSoft,
                          ),
                        ),
                      ],
                    ),
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
