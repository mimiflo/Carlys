import 'dart:convert';

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// Le cœur du besoin : lancer un modèle crée une VRAIE séance, pré-remplie du
/// programme, entièrement hors ligne.
void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine engine;
  late WorkoutRepositoryImpl workouts;
  late WorkoutTemplateRepositoryImpl templates;
  late DateTime clock;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    clock = DateTime.utc(2026, 8, 8, 17);
    engine = SyncEngine(database: db, api: api, now: () => clock);
    workouts = WorkoutRepositoryImpl(database: db, syncEngine: engine);
    templates = WorkoutTemplateRepositoryImpl(database: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  Future<String> savePushTemplate() {
    return templates.saveTemplate(
      const SaveTemplateInput(
        name: 'Push force',
        exercises: [
          TemplateExerciseInput(
            exerciseId: 'exo-dc',
            exerciseName: 'Développé couché',
            sets: [
              PlannedSetInput(
                kind: SetKind.warmup,
                targetReps: 12,
                targetWeightKg: 40,
                restSeconds: 60,
              ),
              PlannedSetInput(
                targetReps: 8,
                targetWeightKg: 70,
                restSeconds: 120,
              ),
            ],
          ),
          TemplateExerciseInput(
            exerciseName: 'Dips',
            sets: [
              PlannedSetInput(targetReps: 12),
              PlannedSetInput(targetReps: 10),
            ],
          ),
        ],
      ),
    );
  }

  test(
    'lancement hors ligne : séance + plan aplati + opération session.create, '
    'sans le moindre appel réseau',
    () async {
      api.networkDown = true;
      final templateId = await savePushTemplate();

      final sessionId = await templates.startFromTemplate(templateId);

      // 1. Une vraie séance, visible par le domaine séance existant.
      final active = await workouts.watchActiveWorkout().first;
      expect(active, isNotNull);
      expect(active!.session.id, sessionId);
      expect(active.session.status, WorkoutStatus.inProgress);
      expect(active.session.templateId, templateId);
      expect(active.session.templateName, 'Push force');
      expect(active.session.isFromTemplate, isTrue);
      expect(
        active.sets,
        isEmpty,
      ); // rien n'est fait tant que rien n'est validé

      // 2. Le plan, aplati dans l'ordre (exercice, série).
      final plan = await templates.watchSessionPlan(sessionId).first;
      expect(plan, isNotNull);
      expect(plan!.templateName, 'Push force');
      expect(plan.totalCount, 4);
      expect(plan.doneCount, 0);
      expect(
        plan.items.map((item) => (item.exercisePosition, item.setPosition)),
        [(0, 0), (0, 1), (1, 0), (1, 1)],
      );
      expect(plan.items.first.exerciseName, 'Développé couché');
      expect(plan.items.first.kind, SetKind.warmup);
      expect(plan.items.first.targetReps, 12);
      expect(plan.items.first.targetWeightKg, 40);
      expect(plan.items.first.restSeconds, 60);
      expect(plan.items.last.exerciseName, 'Dips');
      expect(plan.items.last.targetWeightKg, isNull);
      expect(plan.current!.setPosition, 0);
      expect(plan.progressOfExercise(0), (0, 2));

      // 3. Une seule opération de séance, enfilée APRÈS `template.save`.
      final operations = await db.select(db.syncOperations).get();
      expect(operations.map((op) => op.operationType), [
        'template.save',
        'session.create',
      ]);
      final payload =
          jsonDecode(operations.last.payload) as Map<String, dynamic>;
      expect(payload['id'], sessionId);
      expect(payload['templateId'], templateId);
      expect(payload['templateName'], 'Push force');

      // 4. Le plan voyage AVEC la séance — c'est ce qui rend la reprise
      // possible sur un autre appareil. Aucune opération supplémentaire.
      final sent = (payload['plan'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(sent, hasLength(4));
      expect(sent.first['exerciseName'], 'Développé couché');
      expect(sent.first['exerciseId'], 'exo-dc');
      expect(sent.first['kind'], 'WARMUP');
      expect(sent.first['targetReps'], 12);
      expect(sent.first['targetWeightKg'], 40);
      expect(sent.first['restSeconds'], 60);
      // Exercice libre : pas d'identifiant, mais toujours un nom.
      expect(sent.last.containsKey('exerciseId'), isFalse);
      expect(sent.last['exerciseName'], 'Dips');
      expect(operations, hasLength(2));
      expect(api.log, isEmpty);
    },
  );

  test(
    'le dernier lancement est mémorisé, sans opération supplémentaire',
    () async {
      api.networkDown = true;
      final templateId = await savePushTemplate();
      final before = await db.select(db.syncOperations).get();

      await templates.startFromTemplate(templateId);

      final info = (await templates.watchTemplates().first).single;
      expect(info.lastUsedAt, isNotNull);
      // `lastUsedAt` est un miroir de la valeur serveur : il n'est jamais poussé.
      final after = await db.select(db.syncOperations).get();
      expect(after.length, before.length + 1);
      expect(after.last.operationType, 'session.create');
    },
  );

  test(
    'la séance part même si l’enregistrement du modèle a été refusé '
    'définitivement — aucune séance n’est perdue à cause d’un modèle',
    () async {
      api.networkDown = true;
      final templateId = await savePushTemplate();
      api.rejectedIds.add(templateId); // le serveur refusera `template.save`

      final sessionId = await templates.startFromTemplate(templateId);

      api.networkDown = false;
      clock = clock.add(const Duration(minutes: 10));
      await engine.syncNow();

      expect(api.log, ['session.create:$sessionId']);
      final operations = await db.select(db.syncOperations).get();
      expect(
        operations
            .where((op) => op.operationType == 'template.save')
            .single
            .status,
        'failed',
      );
      expect(operations.where((op) => op.status == 'pending'), isEmpty);
      // La séance existe côté local ET a été acceptée côté serveur.
      expect(
        (await workouts.watchActiveWorkout().first)!.session.id,
        sessionId,
      );
    },
  );

  test(
    'au plus une séance en cours : le lancement respecte la règle existante',
    () async {
      api.networkDown = true;
      final templateId = await savePushTemplate();
      await workouts.startWorkout(name: 'Séance libre');

      await expectLater(
        templates.startFromTemplate(templateId),
        throwsStateError,
      );

      // Rien n'a été écrit : ni séance, ni plan.
      expect(await db.select(db.localSessionPlanItems).get(), isEmpty);
      expect(await db.select(db.localWorkoutSessions).get(), hasLength(1));
    },
  );

  test('lancer un modèle inconnu échoue sans rien écrire', () async {
    api.networkDown = true;
    await expectLater(
      templates.startFromTemplate('modele-inexistant'),
      throwsStateError,
    );
    expect(await db.select(db.localWorkoutSessions).get(), isEmpty);
    expect(await db.select(db.localSessionPlanItems).get(), isEmpty);
  });

  test('un modèle supprimé n’est plus lançable', () async {
    api.networkDown = true;
    final templateId = await savePushTemplate();
    await templates.deleteTemplate(templateId);

    await expectLater(
      templates.startFromTemplate(templateId),
      throwsStateError,
    );
  });
}
