/// Constance : les sept jours de la semaine en cours, et la série qui court.
library;

/// Un jour de la semaine affichée.
class ConsistencyDay {
  const ConsistencyDay({
    required this.initial,
    required this.date,
    required this.trained,
    required this.isToday,
    required this.isFuture,
  });

  /// Initiale française du jour : L, M, M, J, V, S, D.
  final String initial;
  final DateTime date;

  /// Une séance a été **terminée** ce jour-là.
  final bool trained;
  final bool isToday;

  /// Jour à venir de la semaine en cours — affiché en retrait, jamais comme
  /// un échec : on ne reproche pas à quelqu'un de ne pas avoir fait demain.
  final bool isFuture;
}

/// Semaine de constance : lundi → dimanche, plus la série en cours.
class ConsistencyWeek {
  const ConsistencyWeek({required this.days, required this.streakDays});

  /// Toujours 7 entrées, de lundi à dimanche.
  final List<ConsistencyDay> days;

  /// Jours consécutifs avec séance, en comptant à rebours depuis aujourd'hui.
  final int streakDays;

  int get trainedCount => days.where((day) => day.trained).length;
}

const List<String> _initials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Construit la semaine à partir des jours où une séance a été terminée.
///
/// [trainedDays] contient des dates LOCALES normalisées à minuit ; [today]
/// aussi. Cette fonction ne connaît ni Drift ni Riverpod : elle est la règle,
/// et rien d'autre.
ConsistencyWeek buildConsistencyWeek({
  required Set<DateTime> trainedDays,
  required DateTime today,
}) {
  final monday = _shiftDays(today, -(today.weekday - 1));

  return ConsistencyWeek(
    days: [
      for (var index = 0; index < 7; index++)
        () {
          final date = _shiftDays(monday, index);
          return ConsistencyDay(
            initial: _initials[index],
            date: date,
            trained: trainedDays.contains(date),
            isToday: date == today,
            isFuture: date.isAfter(today),
          );
        }(),
    ],
    streakDays: _streak(trainedDays, today),
  );
}

/// Série en cours : jours consécutifs avec séance, à rebours depuis
/// aujourd'hui.
///
/// **La journée en cours ne casse jamais la série** : tant qu'elle n'est pas
/// finie, on repart d'hier. Sans cette tolérance, la série tomberait à zéro
/// chaque matin au réveil, ce qui punirait l'utilisateur pour le seul fait
/// d'ouvrir l'application avant sa séance.
int _streak(Set<DateTime> trainedDays, DateTime today) {
  var cursor = trainedDays.contains(today) ? today : _shiftDays(today, -1);
  var count = 0;
  while (trainedDays.contains(cursor)) {
    count++;
    cursor = _shiftDays(cursor, -1);
  }
  return count;
}

/// Décalage de jours **civils**. Passer par le constructeur (plutôt que par
/// `Duration(days:)`) traverse correctement les changements d'heure : une
/// journée d'été fait 23 h ou 25 h, jamais 24 h pile.
DateTime _shiftDays(DateTime day, int delta) =>
    DateTime(day.year, day.month, day.day + delta);
