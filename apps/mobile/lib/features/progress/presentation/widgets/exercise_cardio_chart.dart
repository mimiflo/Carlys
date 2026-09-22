import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import 'progression_chart_frame.dart';

/// La courbe CARDIO d'un exercice : ce qu'on y parcourt, ou ce qu'on y tient.
///
/// Un tapis et un développé couché ne se lisent pas sur la même courbe. La
/// charge maximale d'une course vaut `null`, et la courbe de charge rendait
/// donc « pas encore de courbe » à quelqu'un qui courait depuis six mois :
/// l'écran disait « rien » là où il y avait tout.
///
/// Ce qui passe en ordonnée se décide sur les FAITS ([CardioReading]), pas
/// sur une étiquette d'exercice — une fiche mal catégorisée n'a alors aucune
/// conséquence.
class ExerciseCardioChart extends StatelessWidget {
  /// Pas `const` : l'appelant doit d'abord demander [traceable], et c'est
  /// cette garde-là qui compte.
  ExerciseCardioChart({required this.progression, super.key})
    : assert(
        traceable(progression),
        'une courbe demande au moins deux séances AVEC distance ou chrono',
      );

  final ExerciseProgressionEntity progression;

  /// Vrai quand il y a de quoi tracer : au moins deux séances cardio.
  static bool traceable(ExerciseProgressionEntity progression) =>
      progression.cardioPoints.length >= ProgressionChartFrame.minimumPoints;

  @override
  Widget build(BuildContext context) {
    final points = progression.cardioPoints;
    final distance = progression.cardioReading == CardioReading.distance;

    // Kilomètres et minutes, jamais mètres et secondes : une échelle en
    // secondes écrase la courbe d'une séance à l'autre, et l'axe n'est pas
    // gradué — ce sont les repères de date qui le sont.
    final valeurs = [
      for (final point in points)
        distance ? point.distanceMeters / 1000 : point.durationSeconds / 60,
    ];
    final total = points.fold<int>(
      0,
      (somme, point) =>
          somme + (distance ? point.distanceMeters : point.durationSeconds),
    );

    return ProgressionChartFrame(
      title: distance ? 'Distance par séance' : 'Temps d’effort par séance',
      semanticsLabel: _enonce(valeurs, distance: distance),
      values: valeurs,
      dates: [for (final point in points) point.date],
      color: AppColors.primaryLight,
      areaColor: AppColors.primaryCardSoft,
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          _cumul(total, points.length, distance: distance),
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
      ),
    );
  }

  /// « 42,3 km sur 8 séances » — le cumul dit ce que la courbe ne dit pas :
  /// une série de séances modestes peut faire un gros total.
  static String _cumul(int total, int seances, {required bool distance}) {
    final lu = distance ? formatDistance(total) : formatDuration(total);
    return '${lu.value} ${lu.unit} sur $seances séances';
  }

  /// Ce que le lecteur d'écran annonce : un graphique muet ne dit rien.
  static String _enonce(List<double> valeurs, {required bool distance}) {
    final unite = distance ? 'kilomètres' : 'minutes';
    final quoi = distance ? 'Distance' : 'Temps d’effort';
    return '$quoi par séance, de ${formatDecimal(valeurs.first)} à '
        '${formatDecimal(valeurs.last)} $unite sur ${valeurs.length} séances';
  }
}
