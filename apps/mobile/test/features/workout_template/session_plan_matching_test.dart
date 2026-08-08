import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/domain/usecases/record_planned_set.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// Règle d'appariement plan ↔ série réalisée, et déviations.
///
/// Principe directeur : **aucune déviation n'est une erreur**. L'application
/// enregistre, elle ne juge pas.
void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late WorkoutRepositoryImpl workouts;
  late WorkoutTemplateRepositoryImpl templates;
  late RecordPlannedSet recordSet;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi()..networkDown = true;
    final engine = SyncEngine(
      database: db,
      api: api,
      now: () => DateTime.utc(2026, 8, 8, 17),
    );
    workouts = WorkoutRepositoryImpl(database: db, syncEngine: engine);
    templates = WorkoutTemplateRepositoryImpl(database: db, syncEngine: engine);
    recordSet = RecordPlannedSet(workouts: workouts, templates: templates);
  });

  tearDown(() => db.close());

  /// « Développé couché » 2 × 8 à 60 kg, puis « Dips » 1 × 12.
  Future<String> startPush() async {
    final templateId = await templates.saveTemplate(
      const SaveTemplateInput(
        name: 'Push',
        exercises: [
          TemplateExerciseInput(
            exerciseId: 'exo-dc',
            exerciseName: 'Développé couché',
            sets: [
              PlannedSetInput(targetReps: 8, targetWeightKg: 60),
              PlannedSetInput(targetReps: 8, targetWeightKg: 60),
            ],
          ),
          TemplateExerciseInput(
            exerciseName: 'Dips',
            sets: [PlannedSetInput(targetReps: 12)],
          ),
        ],
      ),
    );
    return templates.startFromTemplate(templateId);
  }

  test('faire moins de répétitions que prévu honore quand même la série',
      () async {
    final sessionId = await startPush();

    final recorded = await recordSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseId: 'exo-dc',
        exerciseName: 'Développé couché',
        reps: 7, // 7 au lieu de 8 : une bonne séance reste une bonne séance
        weightKg: 60,
      ),
    );

    expect(recorded.fulfilled, isNotNull);
    final plan = await templates.sessionPlan(sessionId);
    expect(plan!.doneCount, 1);
    expect(plan.items.first.doneSetId, recorded.setId);
    expect(plan.current!.setPosition, 1); // la 2ᵉ série devient la suivante

    // La série enregistre le RÉEL et conserve la cible affichée.
    final detail = await workouts.workoutDetail(sessionId);
    final set = detail!.sets.single;
    expect(set.reps, 7);
    expect(set.weightKg, 60);
    expect(set.plannedReps, 8);
    expect(set.plannedWeightKg, 60);
    expect(set.deviatesFromPlan, isTrue);
  });

  test('une série supplémentaire n’honore aucun item : jamais plus de 100 %',
      () async {
    final sessionId = await startPush();
    for (var index = 0; index < 3; index++) {
      await recordSet(
        AddSetInput(
          sessionId: sessionId,
          exerciseId: 'exo-dc',
          exerciseName: 'Développé couché',
          reps: 8,
          weightKg: 60,
        ),
      );
    }

    final plan = await templates.sessionPlan(sessionId);
    expect(plan!.totalCount, 3);
    expect(plan.doneCount, 2); // la 3ᵉ série de développé est en trop
    final detail = await workouts.workoutDetail(sessionId);
    expect(detail!.sets, hasLength(3));
    // La série en trop est enregistrée normalement, sans cible.
    expect(detail.sets.last.plannedReps, isNull);
    expect(detail.sets.last.plannedWeightKg, isNull);
  });

  test('un exercice hors programme ne bouge pas le dénominateur', () async {
    final sessionId = await startPush();

    final recorded = await recordSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseName: 'Élévations latérales',
        reps: 15,
        weightKg: 10,
      ),
    );

    expect(recorded.fulfilled, isNull);
    final plan = await templates.sessionPlan(sessionId);
    expect(plan!.totalCount, 3);
    expect(plan.doneCount, 0);
    expect(plan.current!.exerciseName, 'Développé couché');
  });

  test('l’ordre libre est autorisé : l’appariement suit l’exercice choisi',
      () async {
    final sessionId = await startPush();

    final recorded = await recordSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseName: 'Dips', // on commence par la fin du programme
        reps: 12,
      ),
    );

    expect(recorded.fulfilled!.exercisePosition, 1);
    final plan = await templates.sessionPlan(sessionId);
    expect(plan!.doneCount, 1);
    // Le premier item du programme reste à faire.
    expect(plan.current!.exerciseName, 'Développé couché');
    expect(plan.progressOfExercise(1), (1, 1));
  });

  test('passer une série : marquée localement, RIEN n’est envoyé au serveur',
      () async {
    final sessionId = await startPush();
    final plan = await templates.sessionPlan(sessionId);
    final before = (await db.select(db.syncOperations).get()).length;

    await templates.skipPlanItem(plan!.items.first.id);

    final after = await templates.sessionPlan(sessionId);
    expect(after!.items.first.skipped, isTrue);
    expect(after.doneCount, 0);
    expect(after.remainingCount, 2);
    expect(after.current!.setPosition, 1);
    expect((await db.select(db.syncOperations).get()).length, before);

    // La série suivante du même exercice honore l'item suivant, pas le sauté.
    final recorded = await recordSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseId: 'exo-dc',
        exerciseName: 'Développé couché',
        reps: 8,
        weightKg: 60,
      ),
    );
    expect(recorded.fulfilled!.setPosition, 1);
  });

  test('passer un exercice marque toutes ses séries restantes', () async {
    final sessionId = await startPush();
    await recordSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseId: 'exo-dc',
        exerciseName: 'Développé couché',
        reps: 8,
        weightKg: 60,
      ),
    );

    await templates.skipPlanExercise(sessionId: sessionId, exercisePosition: 0);

    final plan = await templates.sessionPlan(sessionId);
    expect(plan!.doneCount, 1); // la série déjà faite reste faite
    expect(plan.items[1].skipped, isTrue);
    expect(plan.current!.exerciseName, 'Dips');
  });

  test('séance libre : le cas d’usage ne change rien au comportement existant',
      () async {
    final sessionId = await workouts.startWorkout(name: 'Séance libre');

    final recorded = await recordSet(
      AddSetInput(sessionId: sessionId, exerciseName: 'Squat', reps: 5),
    );

    expect(recorded.fulfilled, isNull);
    expect(await templates.sessionPlan(sessionId), isNull);
    final detail = await workouts.workoutDetail(sessionId);
    expect(detail!.sets.single.plannedReps, isNull);
  });
}
