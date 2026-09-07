import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import 'section_title_bar.dart';

/// L'EN-TÊTE DE LA SÉANCE DU JOUR : le surtitre, le nom, et la phrase qui
/// dit où en est la séance.
///
/// Séparé de la carte parce que c'est la seule partie qui RAISONNE : elle
/// compte les exercices, les séries et le temps écoulé, là où le reste de la
/// carte ne fait que poser des formes.
class TodayWorkoutHeading extends StatelessWidget {
  const TodayWorkoutHeading({
    required this.title,
    required this.active,
    super.key,
  });

  final String title;
  final WorkoutWithSets? active;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              AppIcons.spark,
              size: SectionTitleBar.iconSize,
              color: AppColors.accent,
            ),
            const SizedBox(width: AppSpacing.xs - 1),
            Text(
              'SÉANCE DU JOUR',
              style: AppTypography.labelMono.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gapTile - 1),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.title.copyWith(
            fontSize: 20,
            letterSpacing: -0.6,
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs - 1),
        Text(
          _support(active),
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }

  /// Ce que la carte peut dire sans rien inventer : les faits mesurés de la
  /// séance en cours, ou la promesse d'une séance libre.
  ///
  /// La durée écoulée tient dans cette phrase plutôt que dans une pastille :
  /// c'est un fait de plus, pas une deuxième chose à regarder.
  static String _support(WorkoutWithSets? active) {
    if (active == null) {
      return 'Tu choisis les exercices en cours de route.';
    }

    final elapsed = _elapsed(active.session.startedAt);
    final since = elapsed == null
        ? 'En cours'
        : 'En cours depuis ${formatDurationShort(elapsed.inSeconds).toLowerCase()}';

    final exercises = active.sets
        .map((entry) => entry.exerciseName)
        .toSet()
        .length;
    final sets = active.setsCount;
    if (exercises == 0) {
      return '$since. Reprends où tu en étais.';
    }
    return '$since — $exercises exercice${exercises > 1 ? 's' : ''}, '
        '$sets série${sets > 1 ? 's' : ''}.';
  }

  /// Temps écoulé depuis le début de la séance ; `null` si l'horloge locale
  /// place le départ dans le futur — on n'affiche alors pas de durée.
  static Duration? _elapsed(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt.toLocal());
    return elapsed.isNegative ? null : elapsed;
  }
}
