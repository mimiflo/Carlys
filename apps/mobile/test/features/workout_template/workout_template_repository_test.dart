import 'dart:convert';

import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_sync_api.dart';

/// Écriture locale d'abord, mise en file ensuite : le modèle de séance suit
/// exactement la discipline offline-first des séances.
void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SyncEngine engine;
  late WorkoutTemplateRepositoryImpl repository;
  late DateTime clock;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = FakeSyncApi();
    clock = DateTime.utc(2026, 8, 8, 10);
    engine = SyncEngine(database: db, api: api, now: () => clock);
    repository =
        WorkoutTemplateRepositoryImpl(database: db, syncEngine: engine);
  });

  tearDown(() => db.close());

  SaveTemplateInput pushInput({String? id, String name = 'Push force'}) {
    return SaveTemplateInput(
      id: id,
      name: name,
      notes: 'Focus haut du pectoral',
      estimatedDurationMinutes: 55,
      exercises: const [
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
            PlannedSetInput(
              targetReps: 8,
              targetWeightKg: 70,
              restSeconds: 120,
            ),
          ],
        ),
        TemplateExerciseInput(
          exerciseName: 'Dips',
          sets: [PlannedSetInput(targetReps: 12)],
        ),
      ],
    );
  }

  Future<List<SyncOperation>> operations() =>
      db.select(db.syncOperations).get();

  test(
      'enregistrer un modèle hors ligne : contenu écrit en local et UNE seule '
      'opération enfilée', () async {
    api.networkDown = true;

    final templateId = await repository.saveTemplate(pushInput());

    final detail = await repository.templateDetail(templateId);
    expect(detail, isNotNull);
    expect(detail!.name, 'Push force');
    expect(detail.notes, 'Focus haut du pectoral');
    expect(detail.exercises, hasLength(2));
    // Les positions sont dérivées de l'ordre des listes, jamais fournies.
    expect(detail.exercises.first.position, 0);
    expect(detail.exercises.last.position, 1);
    expect(detail.exercises.first.sets.map((set) => set.position), [0, 1, 2]);
    expect(detail.exercises.first.sets.first.kind, SetKind.warmup);
    expect(detail.exercises.last.exerciseId, isNull); // exercice libre

    // La carte de liste est calculée localement, disponible hors ligne.
    final list = await repository.watchTemplates().first;
    expect(list, hasLength(1));
    expect(list.single.exercisesCount, 2);
    expect(list.single.plannedSetsCount, 4);
    expect(list.single.previewExerciseNames, ['Développé couché', 'Dips']);
    expect(list.single.syncState, LocalSyncState.pending);

    final pending = await operations();
    expect(pending, hasLength(1));
    expect(pending.single.operationType, 'template.save');
    expect(pending.single.entityType, 'template');
    expect(pending.single.entityId, templateId);
    // L'id de l'entité EST la clé d'idempotence.
    expect(pending.single.idempotencyKey, templateId);
  });

  test('ré-enregistrer remplace INTÉGRALEMENT le contenu local', () async {
    api.networkDown = true;
    final templateId = await repository.saveTemplate(pushInput());
    final first = await repository.templateDetail(templateId);
    final removedExerciseId = first!.exercises.last.id;

    await repository.saveTemplate(
      SaveTemplateInput(
        id: templateId,
        name: 'Push volume',
        exercises: const [
          TemplateExerciseInput(
            exerciseName: 'Développé incliné',
            sets: [PlannedSetInput(targetReps: 10, targetWeightKg: 50)],
          ),
        ],
      ),
    );

    final second = await repository.templateDetail(templateId);
    expect(second!.name, 'Push volume');
    expect(second.exercises, hasLength(1));
    expect(second.exercises.single.exerciseName, 'Développé incliné');
    expect(second.notes, isNull);

    // Les lignes et séries de la version précédente sont physiquement parties.
    final remaining = await db.select(db.localTemplateExercises).get();
    expect(
      remaining.map((line) => line.id),
      isNot(contains(removedExerciseId)),
    );
    expect(await db.select(db.localTemplateSets).get(), hasLength(1));

    // Le PUT décrit l'état complet : la sauvegarde périmée est remplacée.
    final pending = await operations();
    expect(
      pending.where((op) => op.operationType == 'template.save'),
      hasLength(1),
    );
    final body = jsonDecode(pending.single.payload) as Map<String, dynamic>;
    final exercises =
        (body['body'] as Map<String, dynamic>)['exercises'] as List<dynamic>;
    expect(exercises, hasLength(1));
  });

  test('supprimer un modèle pose un tombstone local et une opération rejouable',
      () async {
    api.networkDown = true;
    final templateId = await repository.saveTemplate(pushInput());

    await repository.deleteTemplate(templateId);

    expect(await repository.watchTemplates().first, isEmpty);
    expect(await repository.templateDetail(templateId), isNull);

    // La ligne locale survit jusqu'à l'acquittement (tombstone).
    final row = await (db.select(db.localWorkoutTemplates)
          ..where((template) => template.id.equals(templateId)))
        .getSingleOrNull();
    expect(row, isNotNull);
    expect(row!.deleted, isTrue);

    final pending = await operations();
    expect(pending.map((op) => op.operationType), ['template.delete']);

    // Rejeu : aucune opération supplémentaire.
    await repository.deleteTemplate(templateId);
    expect(await operations(), hasLength(1));
  });

  test('le corps PUT sérialisé respecte le contrat d’API', () async {
    final templateId = await repository.saveTemplate(pushInput());
    await engine.syncNow();

    expect(api.log, ['template.save:$templateId']);
    final body = api.savedTemplates.single;
    expect(body['name'], 'Push force');
    expect(body['estimatedDurationMinutes'], 55);

    final exercises = body['exercises']! as List<dynamic>;
    expect(exercises, hasLength(2));
    final first = exercises.first as Map<String, dynamic>;
    expect(first['exerciseName'], 'Développé couché');
    expect(first['exerciseId'], 'exo-dc');
    // Aucune position transmise : l'ordre du tableau fait foi.
    expect(first.containsKey('position'), isFalse);
    final sets = first['sets']! as List<dynamic>;
    expect(sets, hasLength(3));
    final warmup = sets.first as Map<String, dynamic>;
    expect(warmup['kind'], 'WARMUP');
    expect(warmup['targetReps'], 12);
    expect(warmup['targetWeightKg'], 40);
    expect(warmup.containsKey('position'), isFalse);
    expect((sets[1] as Map<String, dynamic>)['kind'], 'NORMAL');

    // Le modèle acquitté passe `synced`, sans nouvel envoi au rejeu.
    final list = await repository.watchTemplates().first;
    expect(list.single.syncState, LocalSyncState.synced);
    await engine.syncNow();
    expect(api.log, hasLength(1));
  });

  test('une saisie hors bornes est refusée AVANT toute écriture locale',
      () async {
    await expectLater(
      repository.saveTemplate(
        const SaveTemplateInput(name: '   ', exercises: []),
      ),
      throwsA(isA<InvalidTemplateException>()),
    );
    await expectLater(
      repository.saveTemplate(
        const SaveTemplateInput(name: 'Sans exercice', exercises: []),
      ),
      throwsA(isA<InvalidTemplateException>()),
    );
    await expectLater(
      repository.saveTemplate(
        const SaveTemplateInput(
          name: 'Charge absurde',
          exercises: [
            TemplateExerciseInput(
              exerciseName: 'Squat',
              sets: [PlannedSetInput(targetWeightKg: 5000)],
            ),
          ],
        ),
      ),
      throwsA(isA<InvalidTemplateException>()),
    );

    expect(await db.select(db.localWorkoutTemplates).get(), isEmpty);
    expect(await operations(), isEmpty);
  });
}
