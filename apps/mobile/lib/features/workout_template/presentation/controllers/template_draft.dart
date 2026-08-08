/// Brouillon de l'éditeur de modèle — **état d'écran, pas une entité**.
///
/// Le brouillon vit en MÉMOIRE : l'écriture Drift et la mise en file n'ont
/// lieu qu'à « Enregistrer » (décision D7 du contrat). La règle « toute
/// écriture va d'abord en local » protège les données *validées* par
/// l'utilisateur contre une perte réseau ; elle ne demande pas de persister
/// chaque frappe — le faire produirait des modèles fantômes dans la liste et
/// une opération `template.save` par caractère saisi.
///
/// Ce que la règle garde intact : **aucun appel réseau n'est jamais fait avant
/// l'écriture locale**.
library;

import '../../../workout_session/domain/entities/workout.dart';
import '../../domain/entities/workout_template.dart';

/// Une série prévue en cours d'édition.
class DraftSet {
  const DraftSet({
    this.id,
    this.kind = SetKind.normal,
    this.targetReps,
    this.targetWeightKg,
    this.restSeconds,
  });

  /// `null` pour une série qui n'a jamais été enregistrée : le repository lui
  /// attribuera un UUID.
  final String? id;
  final SetKind kind;
  final int? targetReps;

  /// `null` = aucune charge prévue (poids du corps, ou charge décidée le jour
  /// même) — c'est un cas légitime, pas une saisie incomplète.
  final double? targetWeightKg;
  final int? restSeconds;

  DraftSet copyWith({
    SetKind? kind,
    int? targetReps,
    double? Function()? targetWeightKg,
    int? restSeconds,
  }) {
    return DraftSet(
      id: id,
      kind: kind ?? this.kind,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg:
          targetWeightKg == null ? this.targetWeightKg : targetWeightKg(),
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  PlannedSetInput toInput() => PlannedSetInput(
        id: id,
        kind: kind,
        targetReps: targetReps,
        targetWeightKg: targetWeightKg,
        restSeconds: restSeconds,
      );
}

/// Une ligne d'exercice en cours d'édition.
class DraftExercise {
  const DraftExercise({
    required this.localId,
    required this.name,
    required this.sets,
    this.id,
    this.exerciseId,
  });

  /// Identité **de l'écran** : clé de widget stable pendant un réordonnancement
  /// et pendant le pli/dépli. Ce n'est pas un identifiant métier — une ligne
  /// jamais enregistrée n'a pas encore d'[id].
  final String localId;

  final String? id;

  /// `null` pour un exercice libre, hors catalogue.
  final String? exerciseId;
  final String name;
  final List<DraftSet> sets;

  DraftExercise copyWith({List<DraftSet>? sets}) => DraftExercise(
        localId: localId,
        id: id,
        exerciseId: exerciseId,
        name: name,
        sets: sets ?? this.sets,
      );

  TemplateExerciseInput toInput() => TemplateExerciseInput(
        id: id,
        exerciseId: exerciseId,
        exerciseName: name,
        sets: sets.map((set) => set.toInput()).toList(growable: false),
      );
}

/// L'état complet de l'éditeur.
class TemplateDraft {
  const TemplateDraft({
    required this.id,
    required this.name,
    required this.exercises,
    this.notes,
    this.estimatedDurationMinutes,
    this.dirty = false,
  });

  /// Brouillon vide d'une **création** : l'UUID est déjà celui du futur
  /// modèle, généré sur l'appareil avant toute écriture.
  const TemplateDraft.empty(String id)
      : this(id: id, name: '', exercises: const []);

  /// Brouillon amorcé sur un modèle existant — c'est la seule différence
  /// entre créer et modifier.
  factory TemplateDraft.fromDetail(WorkoutTemplateDetail detail) {
    return TemplateDraft(
      id: detail.id,
      name: detail.name,
      notes: detail.notes,
      estimatedDurationMinutes: detail.info.estimatedDurationMinutes,
      exercises: [
        for (final exercise in detail.exercises)
          DraftExercise(
            localId: exercise.id,
            id: exercise.id,
            exerciseId: exercise.exerciseId,
            name: exercise.exerciseName,
            sets: [
              for (final set in exercise.sets)
                DraftSet(
                  id: set.id,
                  kind: set.kind,
                  targetReps: set.targetReps,
                  targetWeightKg: set.targetWeightKg,
                  restSeconds: set.restSeconds,
                ),
            ],
          ),
      ],
    );
  }

  final String id;
  final String name;
  final String? notes;
  final int? estimatedDurationMinutes;
  final List<DraftExercise> exercises;

  /// Modifications non enregistrées : conditionne la confirmation de sortie.
  final bool dirty;

  /// Enregistrable : un nom et au moins un exercice, comme côté serveur.
  bool get canSave => name.trim().isNotEmpty && exercises.isNotEmpty;

  int get plannedSetsCount =>
      exercises.fold(0, (total, exercise) => total + exercise.sets.length);

  TemplateDraft copyWith({
    String? name,
    String? Function()? notes,
    int? Function()? estimatedDurationMinutes,
    List<DraftExercise>? exercises,
    bool dirty = true,
  }) {
    return TemplateDraft(
      id: id,
      name: name ?? this.name,
      notes: notes == null ? this.notes : notes(),
      estimatedDurationMinutes: estimatedDurationMinutes == null
          ? this.estimatedDurationMinutes
          : estimatedDurationMinutes(),
      exercises: exercises ?? this.exercises,
      dirty: dirty,
    );
  }

  /// État final visé du modèle : le `PUT` est un **remplacement intégral**,
  /// les positions se déduisent de l'ordre des listes.
  SaveTemplateInput toInput() => SaveTemplateInput(
        id: id,
        name: name,
        notes: notes,
        estimatedDurationMinutes: estimatedDurationMinutes,
        exercises: exercises.map((it) => it.toInput()).toList(growable: false),
      );
}
