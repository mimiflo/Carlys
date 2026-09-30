import 'dart:io';

import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/academy/data/answered_lessons_store.dart';
import 'package:carlys_mobile/features/academy/presentation/providers/academy_providers.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/account_bound_cache.dart';
import 'package:carlys_mobile/features/community/domain/entities/friend_challenge.dart';
import 'package:carlys_mobile/features/community/presentation/providers/community_providers.dart';
import 'package:carlys_mobile/features/community/presentation/providers/community_tab_state.dart';
import 'package:carlys_mobile/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:carlys_mobile/features/notifications/presentation/providers/notification_preferences.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/meal_photo_cache.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/onboarding/data/first_run_store.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/providers/progress_providers.dart';
import 'package:carlys_mobile/features/progression/data/milestone_push.dart';
import 'package:carlys_mobile/features/progression/data/reward_ledger.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/presentation/providers/reward_providers.dart';
import 'package:carlys_mobile/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/program_providers.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/training_profile_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_nutrition_repository.dart';
import '../support/fake_progress_repository.dart';
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
          () => AccountBoundCache(
            (ref) async => 'CARLYS-${countBuild('codeAmi')}',
            none: '',
          ),
        ),
        answeredLessonsProvider.overrideWith((ref) async {
          countBuild('leconsRepondues');
          return const <String, int>{};
        }),
        earnedRewardsProvider.overrideWith((ref) async {
          countBuild('recompenses');
          return const <EarnedReward>[];
        }),
        personalRecordsProvider.overrideWith(
          () => AccountBoundCache((ref) async {
            countBuild('records');
            return const <PersonalRecordEntry>[];
          }, none: const []),
        ),
        notificationPreferencesProvider.overrideWith(
          () => AccountBoundCache((ref) async {
            countBuild('preferencesNotifications');
            return const <NotificationCategory, bool>{};
          }, none: const {}),
        ),
        lifetimeStatsProvider.overrideWith(
          () => AccountBoundCache((ref) async {
            countBuild('vieEntiere');
            return const LifetimeStats(completedSessions: 200, weeks: []);
          }, none: const LifetimeStats(completedSessions: 0, weeks: [])),
        ),
        trainingProfileProvider.overrideWith(
          () => AccountBoundCache(
            (ref) async {
              countBuild('profilEntrainement');
              return const TrainingProfile(
                goal: null,
                experience: null,
                weeklySessionsTarget: null,
                sessionMinutesTarget: null,
                equipmentSlugs: ['barre', 'rack', 'banc'],
              );
            },
            none: const TrainingProfile(
              goal: null,
              experience: null,
              weeklySessionsTarget: null,
              sessionMinutesTarget: null,
              equipmentSlugs: [],
            ),
          ),
        ),
        nutritionRepositoryProvider.overrideWithValue(
          FakeNutritionRepository(),
        ),
        // Pour `milestonePushProvider`, qui envoie le journal par lui.
        progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
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
      // Même mécanisme pour les deux caches serveur ajoutés à la liste.
      'vieEntiere': 1,
      'profilEntrainement': 1,
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

  test(
    'les compteurs de vie entière et le profil d’entraînement sont relus',
    () async {
      // LE SCÉNARIO DE L'AUDIT. A (200 séances) se déconnecte, B (0 séance)
      // se connecte dans le même processus. Ces deux providers sont
      // PERMANENTS et ne lisent que le réseau : rien dans la purge ne les
      // reconstruisait. B héritait des 200 séances de A, gagnait ses
      // médailles et les poussait sur SON serveur ; une coche de matériel
      // écrivait l'équipement de A sur le profil de B.
      await container.read(lifetimeStatsProvider.future);
      await container.read(trainingProfileProvider.future);
      expect(builds['vieEntiere'], 1);
      expect(builds['profilEntrainement'], 1);

      await container.read(localAccountPurgeProvider).run();

      await container.read(lifetimeStatsProvider.future);
      await container.read(trainingProfileProvider.future);
      expect(
        builds['vieEntiere'],
        2,
        reason: 'les compteurs de vie entière du compte parti survivent',
      );
      expect(
        builds['profilEntrainement'],
        2,
        reason: 'le matériel du compte parti survit à la purge',
      );
    },
  );

  test('une création restée sans réponse ne suit pas le compte', () async {
    // A lance un défi (ou un programme), la réponse se perd, A se
    // déconnecte. Sans la purge, B rouvrait la feuille sur le titre et les
    // amis de A, et rejouait SON identifiant : refusé par le serveur.
    const defi = NewFriendChallenge(
      title: 'Cinq séances',
      metric: ChallengeMetric.workouts,
      durationDays: 7,
      invitedUserIds: ['ami-de-a'],
    );
    const programme = (name: 'Force', weeksCount: 8);
    final idDefiA = container.read(friendChallengeCreationProvider).idFor(defi);
    final idProgrammeA = container
        .read(programCreationProvider)
        .idFor(programme);
    final envoisA = container.read(milestonePushProvider);

    await container.read(localAccountPurgeProvider).run();

    final defis = container.read(friendChallengeCreationProvider);
    final programmes = container.read(programCreationProvider);
    expect(defis.pendingDraft, isNull);
    expect(programmes.pendingDraft, isNull);
    expect(defis.idFor(defi), isNot(idDefiA));
    expect(programmes.idFor(programme), isNot(idProgrammeA));
    // Le dernier journal accepté était celui de A : B remonte le sien.
    expect(container.read(milestonePushProvider), isNot(same(envoisA)));
  });

  test('les photos privées de repas ne restent pas en mémoire', () async {
    final avant = container.read(mealPhotoCacheProvider);

    await container.read(localAccountPurgeProvider).run();

    expect(container.read(mealPhotoCacheProvider), isNot(same(avant)));
  });

  test('tout cache PERMANENT lu au réseau est purgé ou déclaré', () {
    // LE FILET qui manquait : `lifetimeStatsProvider` et
    // `trainingProfileProvider` sont nés après la liste, et personne n'a
    // pensé à les y ajouter. Un `FutureProvider` sans `autoDispose` garde sa
    // valeur tant que le processus vit : il appartient au COMPTE, sauf s'il
    // lit un contenu embarqué ou une préférence de l'appareil. Chaque
    // nouveau venu doit donc choisir son camp ici, par écrit. Un
    // `accountBoundCache` aussi : il se relit de lui-même à la frontière de
    // session, mais la purge est la même frontière vue du disque, et la
    // liste reste l'inventaire complet de ce qui appartient au compte. Une
    // `CreationIdentity` de même : elle garde le brouillon d'un envoi.
    const propresALAppareil = {
      // Contenus EMBARQUÉS dans l'application, les mêmes pour tous.
      'academyPackProvider',
      'recipesPackProvider',
      // La voix du Mentor et sa visite décrivent l'appareil (voir
      // `accountOwnedPreferenceKeys`).
      'mentorPrefsProvider',
      'mentorTourVuesProvider',
    };
    final purge = File(
      'lib/core/database/local_account_purge.dart',
    ).readAsStringSync();
    final declaration = RegExp(
      r'final (\w+) =\s*(?:FutureProvider|accountBoundCache|'
      r'Provider<CreationIdentity)<',
    );
    final oublis = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final match in declaration.allMatches(file.readAsStringSync())) {
        final name = match.group(1)!;
        if (propresALAppareil.contains(name)) continue;
        if (!purge.contains('    $name,')) oublis.add('${file.path} : $name');
      }
    }
    expect(
      oublis,
      isEmpty,
      reason:
          'Ajoute-les à `accountOwnedProviders`, ou à la liste des caches '
          'propres à l’appareil de ce test, avec la raison.',
    );
  });

  test('les records personnels non plus, sous un auditeur permanent', () async {
    // LE PIÈGE QUE CE TEST FIGE. `personalRecordsProvider` était déclaré
    // `autoDispose`, ce qui donnait à croire qu'il se détruisait tout seul
    // et n'avait rien à faire dans la liste de purge. C'était faux : deux
    // Provider PERMANENTS le regardent (`rewardFactsProvider` et
    // `showcaseRewardsProvider`), et l'accueil monte le second dès le
    // lancement via `TitleSummary`. Un auditeur permanent ne relâche
    // jamais : l'élément n'était jamais détruit, et il traversait la purge
    // avec les records de celui qui part. Il est désormais permanent et
    // cache de compte, mais la leçon reste : c'est l'auditeur qui compte.
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
          'un Provider permanent épingle l’élément',
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
