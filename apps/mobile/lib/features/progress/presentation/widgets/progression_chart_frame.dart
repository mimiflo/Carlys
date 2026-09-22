import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// LE CADRE d'une courbe de progression : la carte, le tracé, les repères de
/// date, la sémantique et la note de bas de carte.
///
/// Extrait le jour où une seconde courbe est arrivée (le cardio) : les deux
/// ne diffèrent que par ce qu'elles TRACENT — des kilos ou des kilomètres.
/// Tout le reste (hauteur, révélation au balayage, `RepaintBoundary`, trois
/// dates sous l'axe, énoncé pour le lecteur d'écran) était sur le point
/// d'être recopié, et deux copies divergent toujours par leur sémantique,
/// c'est-à-dire par la moitié qui ne se voit pas.
class ProgressionChartFrame extends StatelessWidget {
  const ProgressionChartFrame({
    required this.title,
    required this.semanticsLabel,
    required this.values,
    required this.dates,
    required this.color,
    required this.areaColor,
    this.highlighted = const {},
    this.footer,
    super.key,
  });

  /// Une courbe se trace entre deux points.
  static const int minimumPoints = 2;

  /// Hauteur du tracé, alignée sur la courbe de poids corporel.
  static const double chartHeight = 104;

  final String title;

  /// Ce que le lecteur d'écran annonce : un graphique muet ne dit rien.
  final String semanticsLabel;

  /// Les ordonnées, du plus ancien au plus récent.
  final List<double> values;

  /// Les dates correspondantes, pour les trois repères sous l'axe.
  final List<DateTime> dates;

  final Color color;
  final Color areaColor;

  /// Index des points à ACCENTUER sur le tracé (les records, côté charge).
  final Set<int> highlighted;

  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    // Une marge d'un centième de l'échelle, jamais nulle : sans elle, une
    // série de valeurs identiques donne `minY == maxY`, que fl_chart rend
    // par une bande vide.
    final marge = ((maxValue - minValue).abs() * 0.1).clamp(1.0, 1e9);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.padCard),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionLabel(title),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: semanticsLabel,
            excludeSemantics: true,
            // Isole le rendu du graphique : ses repeints restent locaux.
            child: RepaintBoundary(
              child: SizedBox(
                height: chartHeight,
                // La courbe SE DESSINE, du plus ancien vers aujourd'hui.
                child: AppRevealSweep(
                  child: LineChart(
                    LineChartData(
                      minY: minValue - marge,
                      maxY: maxValue + marge,
                      lineTouchData: const LineTouchData(enabled: false),
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < values.length; i++)
                              FlSpot(i.toDouble(), values[i]),
                          ],
                          isCurved: true,
                          color: color,
                          barWidth: 2,
                          // Le repère est un POINT ACCENTUÉ sur le tracé, pas
                          // une pastille à côté : la date et la valeur se
                          // lisent alors d'un seul regard.
                          dotData: FlDotData(
                            checkToShowDot: (spot, _) =>
                                highlighted.contains(spot.x.toInt()),
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: AppColors.accent,
                                  strokeWidth: 2,
                                  strokeColor: AppColors.darkSurface,
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: areaColor,
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
              for (final label in marks(dates))
                Text(
                  label,
                  style: AppTypography.resized(
                    AppTypography.labelMono,
                    9,
                  ).copyWith(color: AppColors.darkTextTertiary),
                ),
            ],
          ),
          ?footer,
        ],
      ),
    );
  }

  /// Repères de l'axe : première, médiane et dernière séance RÉELLES — pas
  /// des dates régulières qui ne correspondraient à aucune séance.
  static List<String> marks(List<DateTime> dates) {
    final indexes = <int>{0, dates.length ~/ 2, dates.length - 1}.toList()
      ..sort();
    return [
      for (final index in indexes) formatShortDateMono(dates[index].toLocal()),
    ];
  }
}
