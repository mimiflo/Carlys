import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import 'progression_chart_frame.dart';

/// La courbe de CHARGE d'un exercice, AVEC ses records posés dessus.
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

  final ExerciseProgressionEntity progression;

  /// Vrai quand il y a de quoi tracer : au moins deux séances AVEC charge.
  static bool traceable(ExerciseProgressionEntity progression) =>
      progression.chargedPoints.length >= ProgressionChartFrame.minimumPoints;

  @override
  Widget build(BuildContext context) {
    final points = progression.chargedPoints;

    // Les jours où un record a été posé : ce sont eux qu'on marque.
    final joursRecord = progression.records
        .map((record) => _jour(record.achievedAt))
        .toSet();
    final indexesRecord = <int>{
      for (var i = 0; i < points.length; i++)
        if (joursRecord.contains(_jour(points[i].date))) i,
    };

    return ProgressionChartFrame(
      title: 'Charge maximale par séance',
      semanticsLabel: _enonce(points, indexesRecord.length),
      values: [for (final point in points) point.maxWeightKg!],
      dates: [for (final point in points) point.date],
      color: AppColors.magenta,
      areaColor: AppColors.magentaCardSoft,
      highlighted: indexesRecord,
      footer: indexesRecord.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    AppIcons.record,
                    size: 14,
                    color: AppColors.accent,
                  ),
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

  static DateTime _jour(DateTime moment) {
    final local = moment.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
