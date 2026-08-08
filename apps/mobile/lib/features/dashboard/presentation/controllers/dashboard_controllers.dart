import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/data/repositories/progress_repository_impl.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';

/// Objectif hebdomadaire de séances — référence commune de l'indice de forme
/// et du bloc « Ta semaine ».
const int weeklySessionsTarget = 5;

/// Vue « semaine » de l'accueil — indépendante de la période sélectionnée
/// sur l'onglet Progression.
final weekOverviewProvider =
    FutureProvider.autoDispose<ProgressOverviewEntity>((ref) {
  return ref.watch(progressRepositoryProvider).overview(ProgressPeriod.week);
});

/// Indice de forme : part de l'objectif hebdomadaire déjà réalisée, sur 100.
///
/// `null` tant que la semaine n'est pas chargée — l'écran affiche alors un
/// tiret plutôt qu'une valeur inventée.
final fitnessIndexProvider = Provider.autoDispose<int?>((ref) {
  final week = ref.watch(weekOverviewProvider).valueOrNull;
  if (week == null) {
    return null;
  }
  final done = week.sessionsCount.clamp(0, weeklySessionsTarget);
  return (done / weeklySessionsTarget * 100).round();
});

/// Temps écoulé depuis la fin de la dernière séance terminée — seule base
/// réelle du fait « récupération » affiché en haut de l'accueil.
///
/// `null` si aucune séance terminée n'est connue localement.
final restSinceLastWorkoutProvider = Provider.autoDispose<Duration?>((ref) {
  final history = ref.watch(workoutHistoryProvider).valueOrNull;
  if (history == null) {
    return null;
  }
  for (final entry in history) {
    if (entry.session.status != WorkoutStatus.completed) {
      continue;
    }
    final endedAt = entry.session.endedAt ?? entry.session.startedAt;
    final rest = DateTime.now().difference(endedAt.toLocal());
    return rest.isNegative ? Duration.zero : rest;
  }
  return null;
});
