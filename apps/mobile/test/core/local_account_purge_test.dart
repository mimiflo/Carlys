import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/academy/data/answered_lessons_store.dart';
import 'package:carlys_mobile/features/academy/presentation/controllers/academy_controllers.dart';
import 'package:carlys_mobile/features/community/presentation/controllers/community_controllers.dart';
import 'package:carlys_mobile/features/onboarding/data/first_run_store.dart';
import 'package:carlys_mobile/features/progression/data/reward_ledger.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/reward_controllers.dart';
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

  /// Nombre de constructions de chaque cache de compte : la purge doit les
  /// avoir renouvelés, sinon le compte suivant lit ceux du précédent.
  late Map<String, int> builds;

  int countBuild(String name) => builds[name] = (builds[name] ?? 0) + 1;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      RewardLedger.key: '{"premiere-seance":"2026-09-01T10:00:00.000Z"}',
      AnsweredLessonsStore.key: '{"lecon-1":2}',
      FirstRunStore.answersKey:
          '{"poids":72.5,"taille":178,"objectif":"perte"}',
      'apparence.theme': 'sombre',
      FirstRunStore.stepKey: 'termine',
    });
    opened.clear();
    builds = {};
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(NativeDatabase.memory());
          opened.add(db);
          return db;
        }),
        syncLifecycleProvider.overrideWith((ref) => NoopSyncLifecycle()),
        appRestoreProvider.overrideWith((ref) => NoopAppRestore()),
        // Les trois caches de compte, remplacés par des sources qui se
        // comptent : leur renouvellement est ce qu'on vérifie, pas leur
        // contenu (le serveur et le disque sont testés ailleurs).
        myFriendCodeProvider.overrideWith(
          (ref) async => 'CARLYS-${countBuild('codeAmi')}',
        ),
        answeredLessonsProvider.overrideWith((ref) async {
          countBuild('leconsRepondues');
          return const <String, int>{};
        }),
        earnedRewardsProvider.overrideWith((ref) async {
          countBuild('recompenses');
          return const <EarnedReward>[];
        }),
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
      // Les réponses d'onboarding en attente décrivent une PERSONNE (poids,
      // taille, objectif) et sont rejouées à la prochaine session
      // authentifiée : les garder écrirait le profil de celui qui part sur
      // le compte de celui qui arrive.
      expect(preferences.containsKey(FirstRunStore.answersKey), isFalse);
      // L'étape atteinte, elle, décrit bien l'appareil : le parcours de
      // première ouverture ne se rejoue pas pour le compte suivant.
      expect(preferences.getString(FirstRunStore.stepKey), 'termine');
      expect(preferences.getString('apparence.theme'), 'sombre');
    },
  );

  test('les caches mémoire du compte sont renouvelés', () async {
    // Ces trois providers ne sont pas auto-disposés : sans invalidation, ils
    // survivent à la purge et rendent au compte suivant le code ami, les
    // questions abordées et les récompenses du précédent — le journal des
    // récompenses se réécrirait même sous le nouveau compte.
    expect(await container.read(myFriendCodeProvider.future), 'CARLYS-1');
    expect(await container.read(answeredLessonsProvider.future), isEmpty);
    expect(await container.read(earnedRewardsProvider.future), isEmpty);
    expect(builds, {'codeAmi': 1, 'leconsRepondues': 1, 'recompenses': 1});

    await container.read(localAccountPurgeProvider).run();

    expect(await container.read(myFriendCodeProvider.future), 'CARLYS-2');
    expect(await container.read(answeredLessonsProvider.future), isEmpty);
    expect(await container.read(earnedRewardsProvider.future), isEmpty);
    expect(builds, {'codeAmi': 2, 'leconsRepondues': 2, 'recompenses': 2});
  });
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
