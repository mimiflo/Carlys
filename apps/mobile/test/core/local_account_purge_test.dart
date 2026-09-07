import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/academy/data/answered_lessons_store.dart';
import 'package:carlys_mobile/features/progression/data/reward_ledger.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_workout_repository.dart';

/// À la frontière de compte, l'appareil ne garde rien du compte qui part :
/// toutes les tables, les préférences du compte, et une base neuve pour la
/// suite. Ce qui décrit l'appareil (thème, premier lancement) reste.
void main() {
  late ProviderContainer container;
  late AppDatabase database;

  /// Toutes les bases ouvertes par le conteneur, dans l'ordre : la première
  /// est vidée, la seconde prend le relais. Elles restent ouvertes jusqu'à
  /// la fin du test pour pouvoir être inspectées.
  final opened = <AppDatabase>[];

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      RewardLedger.key: '{"premiere-seance":"2026-09-01T10:00:00.000Z"}',
      AnsweredLessonsStore.key: '{"lecon-1":2}',
      'apparence.theme': 'sombre',
      'parcours.premiere_ouverture.etape': 'termine',
    });
    opened.clear();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(NativeDatabase.memory());
          opened.add(db);
          return db;
        }),
        syncLifecycleProvider.overrideWith((ref) => NoopSyncLifecycle()),
        appRestoreProvider.overrideWith((ref) => NoopAppRestore()),
      ],
    );
    database = container.read(appDatabaseProvider);
    await _fillEveryTable(database);
  });

  tearDown(() async {
    container.dispose();
    for (final db in opened) {
      await db.close();
    }
  });

  test(
    'toutes les tables sont vidées et une base neuve prend le relais',
    () async {
      final lifecycleBefore = container.read(syncLifecycleProvider);
      final restoreBefore = container.read(appRestoreProvider);
      for (final table in database.allTables) {
        expect(
          await database.select(table).get(),
          isNotEmpty,
          reason: table.actualTableName,
        );
      }

      await container.read(localAccountPurgeProvider).run();

      // La base vidée l'est réellement, table par table…
      for (final table in database.allTables) {
        expect(
          await database.select(table).get(),
          isEmpty,
          reason: table.actualTableName,
        );
      }
      // … et le compte suivant repart sur une base NEUVE, avec de nouveaux
      // déclencheurs : il fera son propre rapatriement.
      final databaseAfter = container.read(appDatabaseProvider);
      expect(identical(databaseAfter, database), isFalse);
      expect(opened, hasLength(2));
      expect(
        await databaseAfter.select(databaseAfter.syncOperations).get(),
        isEmpty,
      );
      expect(
        identical(container.read(syncLifecycleProvider), lifecycleBefore),
        isFalse,
      );
      expect(
        identical(container.read(appRestoreProvider), restoreBefore),
        isFalse,
      );
    },
  );

  test(
    'les préférences du compte partent, celles de l’appareil restent',
    () async {
      await container.read(localAccountPurgeProvider).run();

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey(RewardLedger.key), isFalse);
      expect(preferences.containsKey(AnsweredLessonsStore.key), isFalse);
      expect(preferences.getString('apparence.theme'), 'sombre');
      expect(
        preferences.getString('parcours.premiere_ouverture.etape'),
        'termine',
      );
    },
  );
}

/// Une ligne dans CHAQUE table : la purge doit les connaître toutes, y
/// compris celles qu'on ajoutera demain (`allTables`).
Future<void> _fillEveryTable(AppDatabase db) async {
  final at = DateTime.utc(2026, 9, 1, 10);
  await db
      .into(db.localWorkoutSessions)
      .insert(
        LocalWorkoutSessionsCompanion.insert(
          id: 's-1',
          status: 'COMPLETED',
          startedAt: at,
        ),
      );
  await db
      .into(db.localWorkoutSets)
      .insert(
        LocalWorkoutSetsCompanion.insert(
          id: 'set-1',
          sessionId: 's-1',
          exerciseName: 'Squat',
          position: 0,
          completedAt: at,
        ),
      );
  await db
      .into(db.localWorkoutTemplates)
      .insert(
        LocalWorkoutTemplatesCompanion.insert(
          id: 't-1',
          name: 'Push',
          updatedAt: at,
        ),
      );
  await db
      .into(db.localTemplateExercises)
      .insert(
        LocalTemplateExercisesCompanion.insert(
          id: 'te-1',
          templateId: 't-1',
          exerciseName: 'Squat',
          position: 0,
        ),
      );
  await db
      .into(db.localTemplateSets)
      .insert(
        LocalTemplateSetsCompanion.insert(
          id: 'ts-1',
          templateExerciseId: 'te-1',
          position: 0,
        ),
      );
  await db
      .into(db.localSessionPlanItems)
      .insert(
        LocalSessionPlanItemsCompanion.insert(
          id: 'p-1',
          sessionId: 's-1',
          exercisePosition: 0,
          exerciseName: 'Squat',
          setPosition: 0,
        ),
      );
  await db
      .into(db.localWaterIntakes)
      .insert(
        LocalWaterIntakesCompanion.insert(
          day: DateTime(2026, 9, 1),
          milliliters: const Value(500),
          updatedAt: at,
        ),
      );
  await db
      .into(db.syncOperations)
      .insert(
        SyncOperationsCompanion.insert(
          id: 'op-1',
          entityType: 'session',
          entityId: 's-1',
          operationType: 'session.create',
          payload: '{}',
          createdAt: at,
          idempotencyKey: 's-1',
          ownerUserId: const Value('user-a'),
        ),
      );
}
