import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';

/// La courbe de charge d'un exercice, AVEC ses records posés dessus.
///
/// La spécification dit « une courbe performances + records » : un seul
/// objet, pas deux blocs empilés. Un record est un point de la courbe — le
/// jour où la charge a dépassé tout le reste — et le montrer ailleurs
/// oblige à faire la correspondance de tête.
class ExerciseProgressionChart extends StatelessWidget {
  /// Pas `const` : l'appelant doit d'abord demander [traceable], et c'est
  /// cette garde-là qui compte. Un constructeur constant obligerait à
  /// vérifier la même chose deux fois, ou à tracer une ligne plate.
  ExerciseProgressionChart({required this.progression, super.key})
    : assert(
        traceable(progression),
        'une courbe demande au moins deux séances AVEC charge',
      );

  /// Une courbe se trace entre deux points.
  static const int minimumPoints = 2;

  /// Hauteur du tracé, alignée sur la courbe de poids corporel.
  static const double chartHeight = 104;

  final ExerciseProgressionEntity progression;

  /// Vrai quand il y a de quoi tracer : au moins deux séances AVEC charge.
  static bool traceable(ExerciseProgressionEntity progression) =>
      progression.chargedPoints.length >= minimumPoints;

  @override
  Widget build(BuildContext context) {
    final points = progression.chargedPoints;
    final charges = points.map((point) => point.maxWeightKg!);
    final minCharge = charges.reduce((a, b) => a < b ? a : b);
    final maxCharge = charges.reduce((a, b) => a > b ? a : b);

    // Les jours où un record a été posé : ce sont eux qu'on marque.
    final joursRecord = progression.records
        .map((record) => _jour(record.achievedAt))
        .toSet();
    final indexesRecord = <int>{
      for (var i = 0; i < points.length; i++)
        if (joursRecord.contains(_jour(points[i].date))) i,
    };

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
          const AppSectionLabel('Charge maximale par séance'),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            label: _enonce(points, indexesRecord.length),
            excludeSemantics: true,
            // Isole le rendu du graphique : ses repeints restent locaux.
            child: RepaintBoundary(
              child: SizedBox(
                height: chartHeight,
                // La courbe SE DESSINE, du plus ancien vers aujourd'hui.
                child: AppRevealSweep(
                  child: LineChart(
                    LineChartData(
                      minY: minCharge - 1,
                      maxY: maxCharge + 1,
                      lineTouchData: const LineTouchData(enabled: false),
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            for (var i = 0; i < points.length; i++)
                              FlSpot(i.toDouble(), points[i].maxWeightKg!),
                          ],
                          isCurved: true,
                          color: AppColors.magenta,
                          barWidth: 2,
                          // Le repère de record est un POINT ACCENTUÉ sur le
                          // tracé, pas une pastille à côté : la date et la
                          // charge se lisent alors d'un seul regard.
                          dotData: FlDotData(
                            checkToShowDot: (spot, _) =>
                                indexesRecord.contains(spot.x.toInt()),
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
              for (final label in _reperes(points))
                Text(
                  label,
                  style: AppTypography.resized(
                    AppTypography.labelMono,
                    9,
                  ).copyWith(color: AppColors.darkTextTertiary),
                ),
            ],
          ),
          if (indexesRecord.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(AppIcons.record, size: 14, color: AppColors.accent),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  indexesRecord.length == 1
                      ? 'Le point accentué est un record'
                      : 'Les points accentués sont tes records',
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Ce que le lecteur d'écran annonce : un graphique muet ne dit rien.
  static String _enonce(List<ExerciseProgressionPoint> points, int records) {
    final premiere = formatDecimal(points.first.maxWeightKg!);
    final derniere = formatDecimal(points.last.maxWeightKg!);
    final marque = records == 0
        ? ''
        : ', dont $records record${records > 1 ? 's' : ''}';
    return 'Charge maximale par séance, de $premiere à $derniere kilos '
        'sur ${points.length} séances$marque';
  }

  /// Repères de la courbe : première, médiane et dernière séance réelles.
  static List<String> _reperes(List<ExerciseProgressionPoint> points) {
    final indexes = <int>{0, points.length ~/ 2, points.length - 1}.toList()
      ..sort();
    return [
      for (final index in indexes)
        formatShortDateMono(points[index].date.toLocal()),
    ];
  }

  static DateTime _jour(DateTime moment) {
    final local = moment.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
