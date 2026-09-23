import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/academy/data/answered_lessons_store.dart';
import 'package:carlys_mobile/features/academy/presentation/controllers/academy_controllers.dart';
import 'package:carlys_mobile/features/community/presentation/controllers/community_controllers.dart';
import 'package:carlys_mobile/features/community/presentation/providers/community_tab_state.dart';
import 'package:carlys_mobile/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:carlys_mobile/features/notifications/presentation/controllers/notification_preferences.dart';
import 'package:carlys_mobile/features/onboarding/data/first_run_store.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/controllers/progress_controllers.dart';
import 'package:carlys_mobile/features/progression/data/reward_ledger.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/reward_controllers.dart';
import 'package:carlys_mobile/features/subscription/presentation/controllers/subscription_controllers.dart';
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
        personalRecordsProvider.overrideWith((ref) async {
          countBuild('records');
          return const <PersonalRecordEntry>[];
        }),
        notificationPreferencesProvider.overrideWith((ref) async {
          countBuild('preferencesNotifications');
          return const <NotificationCategory, bool>{};
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
    // `records` apparaît à 1 sans que ce test l'ait jamais lu : l'invalidation
    // de la purge le construit. C'est le comportement attendu, et il n'est pas
    // nouveau — `myFriendCodeProvider`, dans la même liste, est aussi un appel
    // réseau refait à la purge. Le test qui suit vérifie ce qui compte
    // vraiment : que ce renouvellement ait bien lieu.
    expect(builds, {
      'codeAmi': 2,
      'leconsRepondues': 2,
      'recompenses': 2,
      'records': 1,
      'preferencesNotifications': 1,
    });
  });

  test('la clé d’idempotence de PAIEMENT ne suit pas le compte', () async {
    // Elle est retenue par offre, pour qu'un double appui rouvre la MÊME
    // page de paiement. Chez le prestataire, elle désigne donc la session
    // créée pour le compte d'AVANT — et le provider qui la porte est
    // permanent. Sans ce renouvellement, le compte suivant qui achetait la
    // même offre sur cet appareil tombait sur la page de paiement de
    // quelqu'un d'autre.
    final avant = container.read(subscriptionActionsProvider);

    await container.read(localAccountPurgeProvider).run();

    expect(container.read(subscriptionActionsProvider), isNot(same(avant)));
  });

  test(
    'la loupe et l’onglet de la Communauté ne suivent pas le compte',
    () async {
      // Deux providers PERMANENTS, voulus tels pour survivre à un détour par un
      // autre onglet de la barre du bas. Sur un téléphone partagé, le compte
      // suivant ouvrait la page filtrée sur le prénom d'un ami du précédent.
      container.read(communitySearchProvider.notifier).state = 'sarah';
      container.read(communityTabProvider.notifier).state = CommunityTab.amis;

      await container.read(localAccountPurgeProvider).run();

      expect(container.read(communitySearchProvider), isNull);
      expect(container.read(communityTabProvider), CommunityTab.defis);
    },
  );

  test('les réglages de notifications ne suivent pas le compte', () async {
    // Ce que la personne accepte de recevoir la décrit, ELLE. Le provider
    // n'est pas auto-disposé et l'écran des réglages le relit tel quel : sans
    // purge, le compte suivant ouvrait Réglages et y voyait les choix du
    // précédent.
    expect(
      await container.read(notificationPreferencesProvider.future),
      isEmpty,
    );
    expect(builds['preferencesNotifications'], 1);

    await container.read(localAccountPurgeProvider).run();

    await container.read(notificationPreferencesProvider.future);
    expect(
      builds['preferencesNotifications'],
      2,
      reason: 'les réglages du compte parti survivent à la purge',
    );
  });

  test(
    'le rapatriement EN VOL est annulé et attendu AVANT le vidage',
    () async {
      // LE SCÉNARIO. Le compte A ouvre l'accueil : le rapatriement part (des
      // dizaines de GET, chacun suivi d'une écriture). A se déconnecte.
      // Invalider le provider n'annule PAS le futur déjà lancé : une écriture
      // qui aboutissait entre le vidage et la fermeture réinjectait les
      // séances de A dans le fichier SQLite que le compte suivant rouvre —
      // et le marqueur de propriétaire venant d'être effacé, plus rien ne les
      // purgeait jamais. L'espion écrit PENDANT qu'on l'attend : si la purge
      // attend vraiment, son écriture est emportée par le vidage.
      final espion = _RapatriementEnVol(database);
      final local = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          syncLifecycleProvider.overrideWith((ref) => NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(espion),
        ],
      );
      addTearDown(local.dispose);

      await local.read(localAccountPurgeProvider).run();

      expect(espion.annule, isTrue);
      expect(
        await database.select(database.localWorkoutSessions).get(),
        isEmpty,
      );
    },
  );

  test('les records personnels non plus, malgré leur autoDispose', () async {
    // LE PIÈGE QUE CE TEST FIGE. `personalRecordsProvider` est déclaré
    // `autoDispose`, ce qui donne à croire qu'il se détruit tout seul et
    // n'a donc rien à faire dans la liste de purge. C'est faux ici : deux
    // Provider PERMANENTS le regardent (`rewardFactsProvider` et
    // `showcaseRewardsProvider`), et l'accueil monte le second dès le
    // lancement via `TitleSummary`. Un auditeur permanent ne relâche
    // jamais : l'élément auto-disposé n'est jamais détruit, et il traverse
    // la purge avec les records de celui qui part. Sur un téléphone
    // partagé, le compte suivant voyait les records du précédent.
    final abonnement = container.listen(showcaseRewardsProvider, (_, _) {});
    addTearDown(abonnement.close);
    await container.read(personalRecordsProvider.future);
    expect(builds['records'], 1);

    await container.read(localAccountPurgeProvider).run();

    await container.read(personalRecordsProvider.future);
    expect(
      builds['records'],
      2,
      reason:
          'les records du compte parti survivent à la purge : '
          'un Provider permanent épingle l’élément auto-disposé',
    );
  });
}

/// Un rapatriement dont une écriture aboutit PENDANT qu'on l'attend : c'est
/// la fenêtre que la purge doit refermer avant de vider la base.
class _RapatriementEnVol implements AppRestore {
  _RapatriementEnVol(this._db);

  final AppDatabase _db;
  bool annule = false;

  @override
  void ensureRestored() {}

  @override
  Future<void> cancelAndWait() async {
    annule = true;
    await _db
        .into(_db.localWorkoutSessions)
        .insert(
          LocalWorkoutSessionsCompanion.insert(
            id: 'seance-en-vol',
            status: 'COMPLETED',
            startedAt: DateTime.utc(2026, 9, 1, 11),
          ),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
