/// OÙ EN EST UN PROGRAMME, et à quel rythme il se joue.
///
/// Deux lectures pures d'un programme, sans horloge ni réseau : le jour de
/// référence est passé en paramètre, comme pour la maxime du jour.
///
/// L'avancement se compte en JOURS CIVILS depuis le premier jour du plan,
/// jamais en séances faites : relier une séance à une case est le travail du
/// calendrier daté, que le serveur déduit. Le profil dit la POSITION dans le
/// plan, le calendrier dit ce qui a été fait — deux questions, deux écrans.
library;

import '../../../core/utilities/civil_days.dart';
import 'entities/program.dart';
import 'entities/program_calendar.dart';

/// Où se situe aujourd'hui dans la durée du plan.
enum ProgramPhase {
  /// Le premier jour est encore à venir.
  upcoming,

  /// Aujourd'hui tombe dans le plan.
  running,

  /// Le dernier jour est passé.
  finished,
}

/// La position d'aujourd'hui dans un programme daté.
class ProgramAdvancement {
  const ProgramAdvancement({
    required this.phase,
    required this.weekNumber,
    required this.weeksCount,
    required this.elapsedDays,
    required this.totalDays,
    required this.daysUntilStart,
  });

  final ProgramPhase phase;

  /// Semaine en cours, de 1 à [weeksCount] — 1 avant le départ, la
  /// dernière une fois le plan fini.
  final int weekNumber;
  final int weeksCount;

  /// Jours du plan ENTIÈREMENT passés : le jour en cours ne compte pas
  /// encore. Le premier jour vaut donc 0 %, le lendemain du dernier 100 %.
  final int elapsedDays;
  final int totalDays;

  /// Jours avant le premier jour, 0 dès qu'il est arrivé.
  final int daysUntilStart;

  double get ratio => totalDays == 0 ? 0 : elapsedDays / totalDays;

  /// Pourcentage TRONQUÉ : 99,9 % du plan n'est pas « 100 % du programme »,
  /// et l'arrondi l'annoncerait fini la veille de son dernier jour.
  int get percent => (ratio * 100).floor();
}

/// L'avancement du plan au jour [today], ou `null` s'il n'est pas daté.
///
/// Sans premier jour, un programme n'est qu'une grille (semaine N, jour J) :
/// aucune position ne se calcule, et en inventer une serait pire que de ne
/// rien dire.
ProgramAdvancement? programAdvancement({
  required DayKey? startsOn,
  required int weeksCount,
  required DateTime today,
}) {
  if (startsOn == null || weeksCount <= 0) {
    return null;
  }
  final totalDays = weeksCount * DateTime.daysPerWeek;
  final sinceStart = joursCivilsEntre(asLocalDate(startsOn), today);
  final elapsed = sinceStart.clamp(0, totalDays);
  final phase = sinceStart < 0
      ? ProgramPhase.upcoming
      : sinceStart >= totalDays
      ? ProgramPhase.finished
      : ProgramPhase.running;

  return ProgramAdvancement(
    phase: phase,
    weekNumber: (elapsed ~/ DateTime.daysPerWeek + 1).clamp(1, weeksCount),
    weeksCount: weeksCount,
    elapsedDays: elapsed,
    totalDays: totalDays,
    daysUntilStart: sinceStart < 0 ? -sinceStart : 0,
  );
}

/// Le rythme d'un programme : ce que la carte en dit en une ligne.
class ProgramRhythm {
  const ProgramRhythm({required this.sessionsPerWeek, required this.total});

  /// Séances par semaine quand TOUTES les semaines en portent autant,
  /// `null` sinon : une moyenne (« 3,5 séances par semaine ») décrirait une
  /// semaine qui n'existe dans aucun plan.
  final int? sessionsPerWeek;

  /// Séances de tout le plan.
  final int total;
}

/// Compte les séances d'un plan : un jour qui n'est pas un repos.
///
/// Une activité libre (« Course ») compte, parce qu'on s'y entraîne ; un
/// repos non, même s'il porte un intitulé.
ProgramRhythm programRhythm(ProgramDetail program) {
  final perWeek = List<int>.filled(program.weeksCount, 0);
  var total = 0;
  for (final day in program.days) {
    final index = day.weekNumber - 1;
    if (day.isRest || index < 0 || index >= perWeek.length) {
      continue;
    }
    perWeek[index]++;
    total++;
  }
  final uniform =
      perWeek.isNotEmpty && perWeek.every((count) => count == perWeek.first);
  return ProgramRhythm(
    sessionsPerWeek: uniform ? perWeek.first : null,
    total: total,
  );
}
