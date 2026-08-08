import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout_session/domain/entities/workout.dart';
import 'template_draft.dart';
import 'workout_template_controllers.dart';

/// Contrôleur du brouillon d'éditeur, **une instance par modèle édité**.
///
/// Il ne touche jamais à la base : il charge l'état de départ (modèle existant
/// ou brouillon vide), puis ne fait qu'assembler l'état visé. C'est l'écran
/// qui, à « Enregistrer », transmet [TemplateDraft.toInput] au repository.
class TemplateEditorController
    extends AutoDisposeFamilyAsyncNotifier<TemplateDraft, String> {
  /// Valeurs de départ d'une série ajoutée sans modèle à recopier — ce sont
  /// des valeurs de formulaire, jamais présentées comme une prescription.
  static const int defaultReps = 8;
  static const int defaultRestSeconds = 90;

  /// Compteur des identités d'écran des lignes ajoutées ici (clés de widget) —
  /// jamais un identifiant métier : celui-ci est attribué par le repository.
  int _nextLocalId = 0;

  @override
  Future<TemplateDraft> build(String templateId) async {
    final detail =
        await ref.watch(workoutTemplateDetailProvider(templateId).future);
    // `null` est le cas normal d'une CRÉATION : l'éditeur part d'un brouillon
    // vide portant déjà l'identifiant du futur modèle.
    return detail == null
        ? TemplateDraft.empty(templateId)
        : TemplateDraft.fromDetail(detail);
  }

  TemplateDraft get _draft => state.requireValue;

  void _update(TemplateDraft draft) => state = AsyncData(draft);

  void setName(String name) => _update(_draft.copyWith(name: name));

  void setNotes(String notes) => _update(
        _draft.copyWith(notes: () => notes.trim().isEmpty ? null : notes),
      );

  /// Durée estimée en minutes ; une saisie vide ou illisible la retire.
  void setEstimatedDuration(String raw) {
    final parsed = int.tryParse(raw.trim());
    _update(_draft.copyWith(estimatedDurationMinutes: () => parsed));
  }

  /// Ajoute une ligne d'exercice, pré-remplie d'une première série prévue.
  void addExercise({required String name, String? exerciseId}) {
    _update(
      _draft.copyWith(
        exercises: [
          ..._draft.exercises,
          DraftExercise(
            localId: 'brouillon-${_nextLocalId++}',
            exerciseId: exerciseId,
            name: name,
            sets: const [
              DraftSet(
                targetReps: defaultReps,
                restSeconds: defaultRestSeconds,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void removeExercise(int index) {
    final exercises = [..._draft.exercises]..removeAt(index);
    _update(_draft.copyWith(exercises: exercises));
  }

  /// Réordonne les lignes. Les positions ne sont jamais saisies : elles se
  /// déduisent de l'ordre de cette liste, ici comme sur le réseau.
  ///
  /// [newIndex] est l'index d'arrivée **après** retrait de l'élément déplacé
  /// (convention de `onReorderItem`).
  void moveExercise(int oldIndex, int newIndex) {
    final exercises = [..._draft.exercises];
    exercises.insert(newIndex, exercises.removeAt(oldIndex));
    _update(_draft.copyWith(exercises: exercises));
  }

  /// Ajoute une série prévue en **recopiant la dernière** : composer « 4 × 8 à
  /// 70 kg » se fait alors en trois appuis, pas en douze.
  void addSet(int exerciseIndex) {
    final exercise = _draft.exercises[exerciseIndex];
    final last = exercise.sets.isEmpty ? null : exercise.sets.last;
    _replaceSets(exerciseIndex, [
      ...exercise.sets,
      DraftSet(
        kind: last?.kind ?? SetKind.normal,
        targetReps: last?.targetReps ?? defaultReps,
        targetWeightKg: last?.targetWeightKg,
        restSeconds: last?.restSeconds ?? defaultRestSeconds,
      ),
    ]);
  }

  void removeSet(int exerciseIndex, int setIndex) {
    final sets = [..._draft.exercises[exerciseIndex].sets]..removeAt(setIndex);
    // Un exercice sans série prévue n'a pas de sens : la ligne disparaît avec
    // sa dernière série, plutôt que d'être refusée à l'enregistrement.
    if (sets.isEmpty) {
      removeExercise(exerciseIndex);
      return;
    }
    _replaceSets(exerciseIndex, sets);
  }

  void updateSet(int exerciseIndex, int setIndex, DraftSet set) {
    final sets = [..._draft.exercises[exerciseIndex].sets];
    sets[setIndex] = set;
    _replaceSets(exerciseIndex, sets);
  }

  void _replaceSets(int exerciseIndex, List<DraftSet> sets) {
    final exercises = [..._draft.exercises];
    exercises[exerciseIndex] = exercises[exerciseIndex].copyWith(sets: sets);
    _update(_draft.copyWith(exercises: exercises));
  }
}

final templateEditorControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TemplateEditorController, TemplateDraft, String>(
  TemplateEditorController.new,
);
