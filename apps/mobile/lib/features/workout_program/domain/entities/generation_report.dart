/// Ce que le serveur a décidé, et ce qu'il a dû céder.
///
/// Le programme dit CE QU'IL FAUT FAIRE ; ce rapport dit POURQUOI. Il vient
/// du serveur tel quel — l'application ne le recalcule pas et n'en déduit
/// rien : les règles de dosage sont une décision serveur, et deux calculs
/// finiraient par diverger.
library;

/// Un assouplissement consenti, nommé et chiffré.
///
/// Un générateur qui livre en silence un dos à quatre séries quand sa règle
/// en demande douze ment par omission. Chaque ligne d'ici est une phrase que
/// l'écran peut montrer telle quelle.
class GenerationRelaxation {
  const GenerationRelaxation({
    required this.code,
    required this.message,
    this.subject,
    this.expected,
    this.actual,
  });

  /// Nom de la règle assouplie (`R6_GROUPE_SOUS_LE_MINIMUM`…).
  final String code;

  /// Phrase rédigée côté serveur, en français : elle s'affiche telle quelle.
  final String message;

  /// Le groupe musculaire ou le jour concerné, quand il y en a un.
  final String? subject;

  final int? expected;
  final int? actual;
}

/// Les séries hebdomadaires allouées à un groupe, face à leur cible.
class GenerationVolume {
  const GenerationVolume({
    required this.muscleGroup,
    required this.weeklySets,
    required this.targetMin,
    required this.targetMax,
  });

  final String muscleGroup;
  final int weeklySets;
  final int targetMin;
  final int targetMax;

  /// Sous la cible : l'écran le signale plutôt que de laisser croire.
  bool get isShort => weeklySets < targetMin;
}

class GenerationReport {
  const GenerationReport({
    required this.status,
    required this.sessionsPerWeek,
    required this.split,
    required this.templatedDays,
    required this.freeLabelDays,
    required this.restDays,
    required this.templatesCreated,
    required this.weeklyVolume,
    required this.uncoveredGroups,
    required this.relaxations,
    required this.notes,
  });

  /// `satisfied` : toutes les règles tenues. `relaxed` : au moins une cédée.
  final String status;
  final int sessionsPerWeek;

  /// Les noms des séances types de la semaine (« Haut du corps A »…).
  final List<String> split;

  final int templatedDays;

  /// Jours planifiés SANS séance détaillée (course, ateliers) : ils ne
  /// produiront aucune donnée dans l'application, et il faut le dire.
  final int freeLabelDays;

  final int restDays;
  final int templatesCreated;
  final List<GenerationVolume> weeklyVolume;
  final List<String> uncoveredGroups;
  final List<GenerationRelaxation> relaxations;

  /// Phrases d'explication déjà rédigées par le serveur.
  final List<String> notes;

  bool get isSatisfied => status == 'satisfied';
}

/// Ce que rend `PUT /programs/{id}/generate` : le plan ET son explication.
class GeneratedProgramResult {
  const GeneratedProgramResult({
    required this.programId,
    required this.name,
    required this.weeksCount,
    required this.report,
  });

  final String programId;
  final String name;
  final int weeksCount;
  final GenerationReport report;
}
