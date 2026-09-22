/// Traduit l'historique local en [RewardFacts].
///
/// Fonction PURE, séparée du catalogue comme des providers. Elle regarde la
/// vie ENTIÈRE là où [buildProgressionFacts] ne regarde qu'une fenêtre
/// récente : une médaille se gagne une fois, un score se recalcule.
library;

import '../../progress/domain/entities/progress.dart';
import '../../workout_session/domain/entities/workout.dart';
import 'progression.dart';
import 'reward_engine.dart';

/// Rythme considéré comme tenable par l'axe « Équilibre ».
const int balancedWeekMin = 2;
const int balancedWeekMax = 4;

/// [lifetime] : ce que le SERVEUR compte sur la vie entière. Quand il est
/// là, il l'emporte sur [history] — non par préférence, mais parce que
/// l'historique local est plafonné à 60 séances au rapatriement
/// (`WorkoutSessionDownloader.restoredSessionsMax`). Sur un compte à 200
/// séances, un téléphone neuf en dérivait 60, ne re-méritait pas
/// `discipline-150`, et la récompense DISPARAISSAIT — ce que le journal
/// promet justement de ne jamais laisser arriver.
///
/// `null` hors ligne, et l'historique local reprend la main : sous-compter
/// n'efface rien, puisque le journal ne s'écrit qu'en AJOUT. Seul un
/// appareil neuf ET hors ligne verrait moins — et il n'a de toute façon rien
/// à montrer.
RewardFacts buildRewardFacts({
  required List<WorkoutHistoryEntry> history,
  required CarlysTitle reachedTitle,
  LifetimeStats? lifetime,
  int lessonsAnswered = 0,
  int lessonsTotal = 0,
  int academyDomainsCompleted = 0,
  int academyDomainsServed = 0,
  int personalRecords = 0,
}) {
  var completed = 0;
  // Nombre de séances par semaine, la semaine étant repérée par le numéro du
  // lundi qui l'ouvre : deux séances du même dimanche et du lundi suivant
  // n'appartiennent pas à la même semaine.
  final perWeek = <int, int>{};

  if (lifetime != null) {
    completed = lifetime.completedSessions;
    for (final week in lifetime.weeks) {
      perWeek[_weekNumberOfMonday(week.mondayOn)] = week.sessions;
    }
  } else {
    for (final entry in history) {
      if (entry.session.status != WorkoutStatus.completed) continue;
      completed++;
      perWeek.update(
        _weekNumber(entry.session.startedAt),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
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
    academyDomainsCompleted: academyDomainsCompleted,
    academyDomainsServed: academyDomainsServed,
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

/// Le même numéro, depuis le lundi CIVIL servi par le serveur (`YYYY-MM-DD`).
///
/// Une chaîne, jamais un instant : le serveur a déjà découpé les semaines
/// dans le fuseau de la personne, et repasser par un `DateTime` local les
/// redécouperait une seconde fois — un lundi matin deviendrait le dimanche
/// d'avant à l'ouest de Greenwich.
int _weekNumberOfMonday(String mondayOn) {
  final monday = DateTime.parse('${mondayOn}T00:00:00Z');
  return monday.difference(DateTime.utc(1970, 1, 5)).inDays ~/ 7;
}

/// Numéro de la semaine ouverte par le lundi, compté depuis l'origine.
int _weekNumber(DateTime date) {
  final local = date.toLocal();
  final day = DateTime.utc(local.year, local.month, local.day);
  // `weekday` vaut 1 le lundi : on recule jusqu'au lundi de la semaine.
  final monday = day.subtract(Duration(days: day.weekday - 1));
  return monday.difference(DateTime.utc(1970, 1, 5)).inDays ~/ 7;
}
