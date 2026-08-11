/// Programmes multi-semaines : un plan d'entraînement dans le temps.
///
/// Un programme dit **quand** s'entraîner ; le modèle de séance dit **quoi**
/// faire. Chaque jour renvoie à un modèle existant, ou n'annonce qu'un
/// intitulé (repos, activité libre) — il ne duplique jamais un exercice.
library;

/// Libellés courts des jours, 1 = lundi … 7 = dimanche (convention API).
const List<String> programDayLabels = [
  'LUN',
  'MAR',
  'MER',
  'JEU',
  'VEN',
  'SAM',
  'DIM',
];

class ProgramDayEntry {
  const ProgramDayEntry({
    required this.id,
    required this.weekNumber,
    required this.dayOfWeek,
    required this.label,
    required this.isRest,
    this.templateId,
  });

  final String id;

  /// 1 à `weeksCount`.
  final int weekNumber;

  /// 1 (lundi) à 7 (dimanche).
  final int dayOfWeek;

  /// Modèle à jouer ce jour-là, s'il y en a un.
  final String? templateId;

  /// Intitulé affiché — nom du modèle figé à l'enregistrement, ou texte
  /// libre (« Repos », « Course »).
  final String label;

  final bool isRest;
}

class ProgramSummary {
  const ProgramSummary({
    required this.id,
    required this.name,
    required this.weeksCount,
    required this.isActive,
    required this.daysCount,
    required this.updatedAt,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final int weeksCount;

  /// Programme suivi en ce moment — UN SEUL à la fois, imposé par le serveur.
  final bool isActive;

  /// Jours renseignés, repos compris.
  final int daysCount;
  final DateTime updatedAt;
}

class ProgramDetail {
  const ProgramDetail({
    required this.id,
    required this.name,
    required this.weeksCount,
    required this.isActive,
    required this.days,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final int weeksCount;
  final bool isActive;
  final List<ProgramDayEntry> days;

  ProgramDayEntry? dayAt(int weekNumber, int dayOfWeek) {
    for (final day in days) {
      if (day.weekNumber == weekNumber && day.dayOfWeek == dayOfWeek) {
        return day;
      }
    }
    return null;
  }

  ProgramDetail copyWith({
    String? name,
    String? description,
    int? weeksCount,
    bool? isActive,
    List<ProgramDayEntry>? days,
  }) {
    return ProgramDetail(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      weeksCount: weeksCount ?? this.weeksCount,
      isActive: isActive ?? this.isActive,
      days: days ?? this.days,
    );
  }
}
