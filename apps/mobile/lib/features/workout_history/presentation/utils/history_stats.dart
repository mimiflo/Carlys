import '../../../progress/domain/entities/progress.dart';
import '../../../workout_session/domain/entities/workout.dart';

/// Agrégats d'un mois d'historique — dérivés uniquement des séances réelles.
class HistoryMonthStats {
  const HistoryMonthStats({
    required this.month,
    required this.entries,
    required this.volumeByDay,
    required this.recordDays,
    required this.maxDayVolume,
  });

  /// Premier jour du mois affiché, en heure locale.
  final DateTime month;

  /// Séances du mois, plus récentes d'abord.
  final List<WorkoutHistoryEntry> entries;

  /// Volume soulevé par jour du mois (kg), indexé par numéro de jour.
  final Map<int, double> volumeByDay;

  /// Jours où un record personnel a été battu.
  final Set<int> recordDays;

  /// Meilleur volume journalier du mois : référence de l'intensité.
  final double maxDayVolume;

  int get sessionsCount => entries.length;

  bool hasSession(int day) => volumeByDay.containsKey(day);

  bool hasRecord(int day) => recordDays.contains(day);

  /// Intensité 0..1 du jour, rapportée au meilleur jour du mois.
  double intensity(int day) {
    final volume = volumeByDay[day];
    if (volume == null || maxDayVolume <= 0) {
      return 0;
    }
    return (volume / maxDayVolume).clamp(0, 1).toDouble();
  }
}

/// Replie l'historique complet sur le mois demandé.
HistoryMonthStats monthStats({
  required DateTime month,
  required List<WorkoutHistoryEntry> history,
  required List<PersonalRecordEntry> records,
}) {
  final entries = <WorkoutHistoryEntry>[];
  final volumeByDay = <int, double>{};

  for (final entry in history) {
    final local = entry.session.startedAt.toLocal();
    if (local.year != month.year || local.month != month.month) {
      continue;
    }
    entries.add(entry);
    volumeByDay.update(
      local.day,
      (total) => total + entry.totalVolumeKg,
      ifAbsent: () => entry.totalVolumeKg,
    );
  }

  final recordDays = <int>{};
  for (final record in records) {
    final local = record.achievedAt.toLocal();
    if (local.year == month.year && local.month == month.month) {
      recordDays.add(local.day);
    }
  }

  var maxDayVolume = 0.0;
  for (final volume in volumeByDay.values) {
    if (volume > maxDayVolume) {
      maxDayVolume = volume;
    }
  }

  return HistoryMonthStats(
    month: DateTime(month.year, month.month),
    entries: entries,
    volumeByDay: volumeByDay,
    recordDays: recordDays,
    maxDayVolume: maxDayVolume,
  );
}

/// Mois proposés au sélecteur : ceux qui portent des séances, plus le mois
/// courant, du plus récent au plus ancien.
List<DateTime> historyMonths(
  List<WorkoutHistoryEntry> history,
  DateTime reference,
) {
  final months = <int, DateTime>{};

  void register(DateTime date) {
    months[date.year * 12 + date.month] = DateTime(date.year, date.month);
  }

  register(reference.toLocal());
  for (final entry in history) {
    register(entry.session.startedAt.toLocal());
  }

  return months.values.toList()..sort((a, b) => b.compareTo(a));
}
