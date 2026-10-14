import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/presentation/controllers/template_editor_controller.dart';
import 'package:carlys_mobile/features/workout_template/presentation/providers/workout_template_providers.dart';
import 'package:carlys_mobile/features/workout_template/presentation/utils/template_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une série chronométrée (gainage en secondes, course en mètres) ne perd
/// jamais sa durée ni sa distance en traversant une copie : ni la série
/// appariée au plan, ni le modèle rouvert puis réenregistré.
void main() {
  test('l’appariement au plan garde la durée et la distance de la série', () {
    const saisie = AddSetInput(
      sessionId: 's1',
      exerciseName: 'Course',
      durationSeconds: 600,
      distanceMeters: 2000,
    );

    final appariee = saisie.copyWith(planItemId: 'p1');

    expect(appariee.durationSeconds, 600);
    expect(appariee.distanceMeters, 2000);
    expect(appariee.planItemId, 'p1');
  });

  test('un modèle rouvert puis enregistré garde ses cibles chronométrées', () {
    final detail = rameur();

    final serie = TemplateDraft.fromDetail(
      detail,
    ).toInput().exercises.single.sets.single;

    expect(serie.targetDurationSeconds, 600);
    expect(serie.targetDistanceMeters, 2000);
  });

  test(
    'une série ajoutée recopie la durée et la distance, sans répétitions',
    () async {
      final container = ProviderContainer(
        overrides: [
          workoutTemplateDetailProvider('t1').overrideWith((ref) => rameur()),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        templateEditorControllerProvider('t1'),
        (_, __) {},
      );
      addTearDown(sub.close);
      await container.read(templateEditorControllerProvider('t1').future);

      container.read(templateEditorControllerProvider('t1').notifier).addSet(0);

      final ajoutee = container
          .read(templateEditorControllerProvider('t1'))
          .requireValue
          .exercises
          .single
          .sets
          .last;
      expect(ajoutee.targetDurationSeconds, 600);
      expect(ajoutee.targetDistanceMeters, 2000);
      expect(ajoutee.targetReps, isNull);
    },
  );
}

WorkoutTemplateDetail rameur() {
  return WorkoutTemplateDetail(
    info: WorkoutTemplateInfo(
      id: 't1',
      name: 'Cardio',
      exercisesCount: 1,
      plannedSetsCount: 1,
      previewExerciseNames: const ['Rameur'],
      updatedAt: DateTime.utc(2026, 10, 14),
      syncState: LocalSyncState.synced,
    ),
    exercises: const [
      TemplateExerciseEntry(
        id: 'e1',
        exerciseName: 'Rameur',
        position: 0,
        sets: [
          PlannedSet(
            id: 'set1',
            position: 0,
            targetDurationSeconds: 600,
            targetDistanceMeters: 2000,
          ),
        ],
      ),
    ],
  );
}
