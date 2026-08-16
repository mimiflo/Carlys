/// Traduit l'historique local en [RewardFacts].
///
/// Fonction PURE, séparée du catalogue comme des providers. Elle regarde la
/// vie ENTIÈRE là où [buildProgressionFacts] ne regarde qu'une fenêtre
/// récente : une médaille se gagne une fois, un score se recalcule.
library;

import '../../workout_session/domain/entities/workout.dart';
import 'progression.dart';
import 'reward_engine.dart';

/// Rythme considéré comme tenable par l'axe « Équilibre ».
const int balancedWeekMin = 2;
const int balancedWeekMax = 4;

RewardFacts buildRewardFacts({
  required List<WorkoutHistoryEntry> history,
  required CarlysTitle reachedTitle,
  int lessonsAnswered = 0,
  int lessonsTotal = 0,
  int personalRecords = 0,
}) {
  var completed = 0;
  // Nombre de séances par semaine, la semaine étant repérée par le numéro du
  // lundi qui l'ouvre : deux séances du même dimanche et du lundi suivant
  // n'appartiennent pas à la même semaine.
  final perWeek = <int, int>{};

  for (final entry in history) {
    if (entry.session.status != WorkoutStatus.completed) continue;
    completed++;
    perWeek.update(
      _weekNumber(entry.session.startedAt),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  return RewardFacts(
    reachedTitle: reachedTitle,
    completedSessions: completed,
    bestWeekStreak: _bestStreak(perWeek.keys),
    balancedWeeks: perWeek.values
        .where((count) => count >= balancedWeekMin && count <= balancedWeekMax)
        .length,
    lessonsAnswered: lessonsAnswered,
    lessonsTotal: lessonsTotal,
    personalRecords: personalRecords,
  );
}

/// La plus longue suite de semaines consécutives.
///
/// Le RECORD, pas la série en cours : une série cassée reste gagnée. C'est
/// la règle de marque appliquée au calcul — l'absence ne reprend rien.
int _bestStreak(Iterable<int> weeks) {
  final sorted = weeks.toList()..sort();
  var best = 0;
  var run = 0;
  int? previous;
  for (final week in sorted) {
    run = previous != null && week == previous + 1 ? run + 1 : 1;
    if (run > best) best = run;
    previous = week;
  }
  return best;
}

/// Numéro de la semaine ouverte par le lundi, compté depuis l'origine.
int _weekNumber(DateTime date) {
  final local = date.toLocal();
  final day = DateTime.utc(local.year, local.month, local.day);
  // `weekday` vaut 1 le lundi : on recule jusqu'au lundi de la semaine.
  final monday = day.subtract(Duration(days: day.weekday - 1));
  return monday.difference(DateTime.utc(1970, 1, 5)).inDays ~/ 7;
}
