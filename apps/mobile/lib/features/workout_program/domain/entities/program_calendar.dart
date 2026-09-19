/// LE CALENDRIER DATÉ d'un programme : la grille posée sur de vraies dates.
///
/// Tout y est DÉDUIT par le serveur, rien n'y est stocké : « fait » découle
/// du lien séance → jour, « manqué » de la date dans le fuseau de la
/// personne, « hors période » du jour de départ réel. L'application n'a donc
/// aucun état à tenir d'accord avec quoi que ce soit — elle affiche.
library;

/// Un jour civil `AAAA-MM-JJ`, tel que le serveur l'échange.
///
/// Une CHAÎNE, et c'est volontaire : convertie en `DateTime` puis passée au
/// `.toLocal()` que l'application applique partout ailleurs — à raison,
/// puisque tout le reste est un instant — la date reculerait d'un jour à
/// l'ouest de Greenwich. [asLocalDate] fait la conversion À UN SEUL endroit,
/// et sans fuseau.
typedef DayKey = String;

/// Le `DateTime` local de minuit du jour `AAAA-MM-JJ`.
///
/// `DateTime.parse` sans suffixe `Z` rend une date LOCALE : c'est exactement
/// ce qu'on veut d'un jour civil, et c'est pourquoi la conversion ne passe
/// jamais par UTC.
DateTime asLocalDate(DayKey day) => DateTime.parse(day);

/// L'état d'une case, tel que le serveur le déduit.
enum ProgramDayStatus {
  /// Aucune case n'occupe ce jour : rien n'était prévu, rien n'est reproché.
  free('free'),

  /// Repos EXPLICITEMENT planifié — ce n'est pas la même chose que [free].
  rest('rest'),

  /// Une séance terminée porte cette case.
  done('done'),

  /// La date est passée, la séance prévue n'a pas eu lieu.
  missed('missed'),

  /// La case précède le départ réel : elle n'a jamais été promise.
  before('before'),

  /// Aujourd'hui et l'avenir.
  upcoming('upcoming');

  const ProgramDayStatus(this.apiValue);

  final String apiValue;

  /// Une valeur inconnue devient [upcoming] plutôt que de faire échouer la
  /// lecture : un serveur plus récent peut nommer un état que cette version
  /// ignore, et le calendrier doit rester lisible. « À venir » est le seul
  /// repli qui n'accuse personne.
  static ProgramDayStatus fromApi(String? value) {
    for (final status in ProgramDayStatus.values) {
      if (status.apiValue == value) {
        return status;
      }
    }
    return ProgramDayStatus.upcoming;
  }
}

class ProgramCalendarDay {
  const ProgramCalendarDay({
    required this.weekNumber,
    required this.dayOfWeek,
    required this.date,
    required this.status,
    required this.isRest,
    this.id,
    this.templateId,
    this.label,
    this.sessionId,
  });

  /// `null` quand aucune case n'occupe ce jour — le calendrier montre les
  /// sept, y compris les vides.
  final String? id;
  final int weekNumber;

  /// 1 (lundi) à 7 (dimanche).
  final int dayOfWeek;
  final DayKey date;
  final ProgramDayStatus status;
  final String? templateId;
  final String? label;
  final bool isRest;

  /// La séance TERMINÉE qui honore cette case, s'il y en a une.
  final String? sessionId;

  DateTime get localDate => asLocalDate(date);

  /// Vrai quand cette case attend une séance qu'on peut lancer.
  bool get isLaunchable =>
      templateId != null && status != ProgramDayStatus.done;
}

class ProgramCalendarWeek {
  const ProgramCalendarWeek({
    required this.programId,
    required this.name,
    required this.weeksCount,
    required this.startsOn,
    required this.weekNumber,
    required this.today,
    required this.days,
    this.currentWeek,
  });

  final String programId;
  final String name;
  final int weeksCount;
  final DayKey startsOn;

  /// Semaine servie, et celle qui contient aujourd'hui (`null` hors du plan).
  final int weekNumber;
  final int? currentWeek;

  /// Aujourd'hui DANS LE FUSEAU DE LA PERSONNE, décidé par le serveur :
  /// l'écran ne recalcule pas ce qu'il vient de recevoir.
  final DayKey today;
  final List<ProgramCalendarDay> days;

  bool get isCurrentWeek => currentWeek == weekNumber;
}
