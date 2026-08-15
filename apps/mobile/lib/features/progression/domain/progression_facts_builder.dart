/// Traduit l'historique local en [ProgressionFacts].
///
/// Fonction PURE, séparée du moteur de calcul comme des providers : elle sait
/// lire l'historique, elle ne sait pas noter. Cette coupure permet de tester
/// le barème sans base de données, et la lecture sans barème.
library;

import '../../workout_session/domain/entities/workout.dart';
import 'progression_engine.dart';

/// Fenêtre de comparaison de l'axe « Performance », en jours.
const int volumeWindowDays = 28;

/// Construit les faits à partir de ce que l'appareil sait déjà.
///
/// [history] est l'historique local complet, tel que le dépôt de séances le
/// sert : les séances TERMINÉES et ABANDONNÉES, jamais celle en cours. C'est
/// exactement la matière voulue — une séance en cours n'a rien prouvé, et la
/// compter ferait monter le score avant l'effort.
ProgressionFacts buildProgressionFacts({
  required List<WorkoutHistoryEntry> history,
  required DateTime today,
  int lessonsAnswered = 0,
  int lessonsTotal = 0,
}) {
  final completedDays = <DateTime>{};
  var started = 0;
  var completed = 0;
  var recentVolume = 0.0;
  var previousVolume = 0.0;

  final todayNumber = _dayNumber(today);

  for (final entry in history) {
    final session = entry.session;
    final age = todayNumber - _dayNumber(session.startedAt);
    if (age < 0) {
      // Séance datée dans le futur : horloge décalée ou reprise d'un autre
      // fuseau. On l'ignore plutôt que de la compter à contretemps.
      continue;
    }

    // La DISCIPLINE se juge sur la fenêtre récente : une séance abandonnée
    // il y a un an ne doit pas peser sur l'axe aujourd'hui.
    if (age < observationDays) {
      started++;
      if (session.status == WorkoutStatus.completed) {
        completed++;
      }
    }

    if (session.status != WorkoutStatus.completed) {
      continue;
    }

    final day = session.startedAt.toLocal();
    completedDays.add(DateTime(day.year, day.month, day.day));

    if (age < volumeWindowDays) {
      recentVolume += entry.totalVolumeKg;
    } else if (age < volumeWindowDays * 2) {
      previousVolume += entry.totalVolumeKg;
    }
  }

  return ProgressionFacts(
    today: today,
    completedSessionDays: completedDays.toList(growable: false),
    startedSessions: started,
    completedSessions: completed,
    recentVolumeKg: recentVolume,
    previousVolumeKg: previousVolume,
    lessonsAnswered: lessonsAnswered,
    lessonsTotal: lessonsTotal,
  );
}

int _dayNumber(DateTime date) {
  final local = date.toLocal();
  return DateTime.utc(local.year, local.month, local.day)
      .difference(DateTime.utc(1970))
      .inDays;
}
