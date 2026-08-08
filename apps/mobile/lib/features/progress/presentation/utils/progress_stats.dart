/// Statistiques dérivées de la progression.
///
/// Tout ce que l'écran affiche se calcule ICI, à partir des points réels
/// renvoyés par `/progress/overview` : aucune valeur n'est inventée, et une
/// mesure impossible à établir renvoie `null` plutôt qu'un chiffre factice.
library;

import '../../../../core/utilities/formatting.dart';
import '../../domain/entities/progress.dart';

/// Granularité des points renvoyés par l'API : les séances sont regroupées
/// par jour (période « semaine »), par semaine (« mois ») puis par mois
/// (« année »).
enum ProgressBucket { day, week, month }

ProgressBucket bucketOf(ProgressPeriod period) => switch (period) {
      ProgressPeriod.week => ProgressBucket.day,
      ProgressPeriod.month => ProgressBucket.week,
      ProgressPeriod.year => ProgressBucket.month,
    };

/// Libellé de la carte de volume, accordé à la période analysée.
String volumeLabel(ProgressPeriod period) => switch (period) {
      ProgressPeriod.week => 'Volume hebdo',
      ProgressPeriod.month => 'Volume mensuel',
      ProgressPeriod.year => 'Volume annuel',
    };

/// Sous-ligne des tuiles : décrit la fenêtre analysée, sans chiffre supposé.
String periodCaption(ProgressPeriod period) => switch (period) {
      ProgressPeriod.week => 'sur la semaine',
      ProgressPeriod.month => 'sur le mois',
      ProgressPeriod.year => 'sur l’année',
    };

/// Évolution du volume entre le dernier intervalle et le précédent, en %.
///
/// `null` quand l'historique est trop court (moins de deux intervalles) ou
/// que l'intervalle de référence est vide : la pastille est alors masquée.
double? volumeTrendPercent(List<ProgressPoint> points) {
  if (points.length < 2) {
    return null;
  }
  final previous = points[points.length - 2].volumeKg;
  final last = points[points.length - 1].volumeKg;
  if (previous <= 0) {
    return null;
  }
  return (last - previous) / previous * 100;
}

/// Assiduité hebdomadaire : part des semaines couvertes qui comptent au
/// moins une séance, et série de semaines consécutives la plus récente.
class WeeklyAttendance {
  const WeeklyAttendance({required this.percent, required this.streak});

  /// 0..100, arrondi.
  final int percent;

  /// Nombre de semaines actives consécutives jusqu'à la plus récente.
  final int streak;
}

/// `null` dès que le calcul n'est pas honnête : points mensuels (ils ne
/// disent pas quelles semaines ont été actives) ou fenêtre d'une seule
/// semaine (l'assiduité vaudrait mécaniquement 100 %).
WeeklyAttendance? weeklyAttendance(
  List<ProgressPoint> points,
  ProgressPeriod period,
) {
  if (bucketOf(period) == ProgressBucket.month) {
    return null;
  }

  final activeWeeks = <int>{};
  for (final point in points) {
    if (point.sessionsCount > 0) {
      activeWeeks.add(_weekIndex(point.bucketStart));
    }
  }
  if (activeWeeks.isEmpty) {
    return null;
  }

  final first = activeWeeks.reduce((a, b) => a < b ? a : b);
  final last = activeWeeks.reduce((a, b) => a > b ? a : b);
  final coveredWeeks = last - first + 1;
  if (coveredWeeks < 2) {
    return null;
  }

  var streak = 0;
  var cursor = last;
  while (activeWeeks.contains(cursor)) {
    streak++;
    cursor--;
  }

  return WeeklyAttendance(
    percent: (activeWeeks.length / coveredWeeks * 100).round(),
    streak: streak,
  );
}

/// Repères temporels du graphe : début, milieu et fin de la série réelle.
List<String> volumeAxisLabels(
  List<ProgressPoint> points,
  ProgressPeriod period,
) {
  if (points.isEmpty) {
    return const [];
  }
  final indexes = <int>{0, points.length ~/ 2, points.length - 1}.toList()
    ..sort();
  final asMonth = bucketOf(period) == ProgressBucket.month;
  return [
    for (final index in indexes)
      asMonth
          ? formatMonthYearMono(points[index].bucketStart.toLocal())
          : formatShortDateMono(points[index].bucketStart.toLocal()),
  ];
}

/// Index de semaine calendaire (lundi) en arithmétique entière : insensible
/// aux changements d'heure, contrairement à un décalage de `Duration`.
int _weekIndex(DateTime date) {
  final local = date.toLocal();
  final days = DateTime.utc(local.year, local.month, local.day)
      .difference(DateTime.utc(1970))
      .inDays;
  // 1970-01-01 tombe un jeudi : +3 pour caler l'origine sur un lundi.
  return (days + 3) ~/ 7;
}
