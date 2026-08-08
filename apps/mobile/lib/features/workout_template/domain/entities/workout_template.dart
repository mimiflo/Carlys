/// Entités du domaine « modèle de séance » (immuables, écrites à la main).
///
/// Vocabulaire imposé (docs/product/workout-templates.md, §1) :
///  - **modèle de séance** : document PRESCRIPTIF réutilisable — ce qui est
///    prévu ([WorkoutTemplateDetail]) ;
///  - **ligne d'exercice** : un exercice du modèle, à une position donnée
///    ([TemplateExerciseEntry]) ;
///  - **série prévue** : une série prescrite d'une ligne ([PlannedSet]).
///
/// Une **séance** (`WorkoutSession`) et une **série** (`WorkoutSet`) sont des
/// faits : elles vivent dans la fonctionnalité `workout_session` et ne sont
/// jamais remplacées par ces entités-ci.
library;

import '../../../workout_session/domain/entities/workout.dart';

/// Bornes partagées avec l'API (`WORKOUT_TEMPLATE_LIMITS` et
/// `WORKOUT_LIMITS` de `packages/api-contracts`).
///
/// Le client valide AVANT d'écrire : un refus serveur après coup ferait passer
/// l'opération en `failed`, c'est-à-dire en travail perdu.
abstract final class WorkoutTemplateLimits {
  static const int nameMax = 120;
  static const int notesMax = 2000;
  static const int exercisesMax = 30;
  static const int setsPerExerciseMax = 20;
  static const int estimatedDurationMinutesMax = 1440;
  static const int repsMax = 1000;
  static const double weightKgMax = 1000;
  static const int restSecondsMax = 3600;
}

/// Série prévue : des **cibles**, pas des mesures. Les trois sont facultatives
/// (un modèle « 4 × 8 » sans charge prévue est légitime).
class PlannedSet {
  const PlannedSet({
    required this.id,
    required this.position,
    this.kind = SetKind.normal,
    this.targetReps,
    this.targetWeightKg,
    this.restSeconds,
  });

  final String id;

  /// Rang de la série DANS sa ligne d'exercice, contigu à partir de 0.
  final int position;
  final SetKind kind;
  final int? targetReps;
  final double? targetWeightKg;
  final int? restSeconds;
}

/// Ligne d'exercice : un exercice du modèle et ses séries prévues.
class TemplateExerciseEntry {
  const TemplateExerciseEntry({
    required this.id,
    required this.exerciseName,
    required this.position,
    required this.sets,
    this.exerciseId,
    this.notes,
  });

  final String id;

  /// `null` pour un « exercice libre », hors catalogue.
  final String? exerciseId;

  /// Dénormalisé : le modèle survit à la dépublication d'un exercice.
  final String exerciseName;

  /// Rang de la ligne DANS le modèle, contigu à partir de 0.
  final int position;
  final String? notes;
  final List<PlannedSet> sets;
}

/// Carte de la liste « Mes modèles » : tout ce qu'affiche une `AppCard`, sans
/// avoir à charger le contenu complet.
class WorkoutTemplateInfo {
  const WorkoutTemplateInfo({
    required this.id,
    required this.name,
    required this.exercisesCount,
    required this.plannedSetsCount,
    required this.previewExerciseNames,
    required this.updatedAt,
    required this.syncState,
    this.estimatedDurationMinutes,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final int exercisesCount;
  final int plannedSetsCount;
  final int? estimatedDurationMinutes;

  /// Trois premiers exercices, dans l'ordre — sous-titre de la carte.
  final List<String> previewExerciseNames;

  /// Dernier lancement (UTC), `null` si le modèle n'a jamais été lancé.
  final DateTime? lastUsedAt;

  /// Dernière modification (UTC) — tri de la liste, plus récent d'abord.
  final DateTime updatedAt;

  /// État de synchronisation local : la liste s'affiche hors ligne, les
  /// modèles non acquittés portent simplement une pastille.
  final LocalSyncState syncState;
}

/// Modèle complet : la carte + le contenu prescrit.
class WorkoutTemplateDetail {
  const WorkoutTemplateDetail({
    required this.info,
    required this.exercises,
    this.notes,
  });

  final WorkoutTemplateInfo info;
  final String? notes;
  final List<TemplateExerciseEntry> exercises;

  String get id => info.id;
  String get name => info.name;
}

// ── Entrées d'écriture ─────────────────────────────────────────────────────
//
// `id` est FACULTATIF : le repository génère un UUID v4 quand il est absent.
// Un écran ne génère jamais d'identifiant lui-même.

class PlannedSetInput {
  const PlannedSetInput({
    this.id,
    this.kind = SetKind.normal,
    this.targetReps,
    this.targetWeightKg,
    this.restSeconds,
  });

  final String? id;
  final SetKind kind;
  final int? targetReps;
  final double? targetWeightKg;
  final int? restSeconds;
}

class TemplateExerciseInput {
  const TemplateExerciseInput({
    required this.exerciseName,
    required this.sets,
    this.id,
    this.exerciseId,
    this.notes,
  });

  final String? id;
  final String? exerciseId;
  final String exerciseName;
  final String? notes;

  /// Les positions ne sont **jamais** transmises : l'ordre de cette liste fait
  /// foi, côté local comme côté serveur.
  final List<PlannedSetInput> sets;
}

/// État complet visé du modèle : l'enregistrement est un **remplacement
/// intégral** (`PUT`), pas une suite de mutations partielles.
class SaveTemplateInput {
  const SaveTemplateInput({
    required this.name,
    required this.exercises,
    this.id,
    this.notes,
    this.estimatedDurationMinutes,
  });

  final String? id;
  final String name;
  final String? notes;
  final int? estimatedDurationMinutes;
  final List<TemplateExerciseInput> exercises;
}

/// Rejet d'une saisie invalide, AVANT toute écriture locale.
///
/// Volontairement levée côté client : laisser partir un modèle hors bornes
/// reviendrait à le voir refusé par le serveur des heures plus tard, en
/// `failed`, c'est-à-dire perdu.
class InvalidTemplateException implements Exception {
  const InvalidTemplateException(this.message);

  final String message;

  @override
  String toString() => message;
}
