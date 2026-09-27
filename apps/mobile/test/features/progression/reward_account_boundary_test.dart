import 'dart:convert';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/academy/presentation/controllers/academy_controllers.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/presentation/controllers/community_controllers.dart';
import 'package:carlys_mobile/features/notifications/data/repositories/device_token_repository_impl.dart';
import 'package:carlys_mobile/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:carlys_mobile/features/notifications/presentation/controllers/notification_preferences.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/controllers/progress_controllers.dart';
import 'package:carlys_mobile/features/progression/data/reward_ledger.dart';
import 'package:carlys_mobile/features/progression/domain/reward.dart';
import 'package:carlys_mobile/features/progression/presentation/controllers/reward_controllers.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/controllers/training_profile_controllers.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_community_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_training_profile_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/in_memory_device_token_repository.dart';

/// RIEN DU COMPTE PARTI NE TRAVERSE LA FRONTIÈRE DE SESSION.
///
/// Le scénario de la relecture : sur un téléphone partagé, A (200 séances,
/// cinq records) se déconnecte depuis les réglages du Profil pendant que
/// l'accueil, monté dans la coquille, écoute la vitrine des récompenses.
/// Puis B (douze séances) se connecte dans le même processus.
///
/// La purge invalidait bien les compteurs de vie entière, mais un provider
/// ÉCOUTÉ se reconstruit aussitôt : sans session, sa relecture échouait en
/// 401, et Riverpod gardait la valeur de A dans l'erreur. Rien ne la relisait
/// à l'entrée de B : B héritait des 200 séances, gagnait les médailles de A,
/// et les POUSSAIT sur son propre serveur. Le même mécanisme touchait tout
/// cache serveur permanent écouté à ce moment-là — dont les préférences de
/// notifications, montrées par l'écran même où l'on se déconnecte.
void main() {
  late FakeAuthRepository auth;
  late _Serveur serveur;
  late ProviderContainer container;
  final bases = <AppDatabase>[];

  const alice = AuthUser(
    id: 'user-a',
    email: 'alice@example.com',
    displayName: 'Alice',
    emailVerified: true,
    locale: 'fr',
    timezone: 'Europe/Paris',
  );
  const bruno = AuthUser(
    id: 'user-b',
    email: 'bruno@example.com',
    displayName: 'Bruno',
    emailVerified: true,
    locale: 'fr',
    timezone: 'Europe/Paris',
  );

  /// Les médailles que seuls les chiffres de A méritent : B, avec ses douze
  /// séances et sans record, n'a droit qu'à `discipline-10`.
  const medaillesDeA = {
    'discipline-50',
    'discipline-150',
    'performance-1',
    'performance-5',
  };

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    bases.clear();
    auth = FakeAuthRepository(storedSession: true, user: alice);
    serveur = _Serveur(auth);
    container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(NativeDatabase.memory());
          bases.add(db);
          return db;
        }),
        syncLifecycleProvider.overrideWith((ref) => NoopSyncLifecycle()),
        appRestoreProvider.overrideWith((ref) => NoopAppRestore()),
        progressRepositoryProvider.overrideWithValue(serveur.progres),
        communityRepositoryProvider.overrideWithValue(serveur.communaute),
        deviceTokenRepositoryProvider.overrideWithValue(serveur.reglages),
        trainingProfileRepositoryProvider.overrideWithValue(serveur.profil),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        academyPackProvider.overrideWith((ref) async => const []),
        nutritionRepositoryProvider.overrideWithValue(
          FakeNutritionRepository(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    for (final db in bases) {
      await db.close();
    }
  });

  AuthController session() => container.read(authControllerProvider.notifier);

  Future<List<EarnedReward>> recompenses() =>
      container.read(earnedRewardsProvider.future);

  Future<Set<String>> journal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(RewardLedger.key);
    if (raw == null) return const {};
    return (jsonDecode(raw) as Map<String, Object?>).keys.toSet();
  }

  /// A ouvre l'application : l'accueil écoute la vitrine, les réglages
  /// écoutent leurs trois caches — EN PERMANENCE, à travers la déconnexion.
  Future<void> aliceSurSesReglages() async {
    await session().restore();
    for (final ecoute in [
      container.listen(showcaseRewardsProvider, (_, _) {}),
      container.listen(notificationPreferencesProvider, (_, _) {}),
      container.listen(myFriendCodeProvider, (_, _) {}),
      container.listen(trainingProfileProvider, (_, _) {}),
    ]) {
      addTearDown(ecoute.close);
    }
    await container.read(lifetimeStatsProvider.future);
    await container.read(personalRecordsProvider.future);
    await container.read(notificationPreferencesProvider.future);
    await pumpEventQueue();
    expect(
      (await recompenses()).map((e) => e.reward.id),
      containsAll(medaillesDeA),
    );
  }

  /// Déconnexion depuis les réglages, puis B se connecte.
  Future<void> puisBruno() async {
    await session().logout();
    await pumpEventQueue();
    auth.user = bruno;
    await session().login(email: bruno.email, password: 'x');
    await pumpEventQueue();
  }

  test('déconnecté, aucun cache écouté ne questionne le serveur', () async {
    // Les réglages et l'accueil restent montés à travers la déconnexion :
    // chaque cache de compte écouté se relit alors. Sans session, il vaut
    // « rien » sans rien demander — un GET sans jeton ne rapporterait
    // qu'un 401, et un état d'erreur à la place du vide.
    await aliceSurSesReglages();

    await session().logout();
    await pumpEventQueue();

    expect(serveur.appelsSansSession, 0);
    expect(
      container.read(lifetimeStatsProvider).valueOrNull?.completedSessions,
      0,
    );
  });

  test('B lit SES compteurs et SES records, pas ceux de A', () async {
    await aliceSurSesReglages();
    await puisBruno();

    expect(
      (await container.read(lifetimeStatsProvider.future)).completedSessions,
      12,
    );
    expect(await container.read(personalRecordsProvider.future), isEmpty);
    await pumpEventQueue();
    expect(container.read(rewardFactsProvider)?.completedSessions, 12);
    expect(
      (await recompenses()).map((e) => e.reward.id),
      isNot(anyElement(isIn(medaillesDeA))),
    );
    expect(
      container.read(showcaseRewardsProvider).map((e) => e.reward.id),
      isNot(anyElement(startsWith('record-'))),
      reason: 'la vitrine de B montrait les records de A',
    );
  });

  test('rien de A ne s’écrit au journal ni sur le serveur de B', () async {
    await aliceSurSesReglages();
    await puisBruno();
    await recompenses();
    await pumpEventQueue();

    expect(await journal(), isNot(anyElement(isIn(medaillesDeA))));
    expect(
      serveur.progres.poussesPar[bruno.id] ?? const <String>{},
      isNot(anyElement(isIn(medaillesDeA))),
      reason: 'les médailles de A remontaient sur le compte de B',
    );
  });

  test('l’histoire de B se reconstruit en silence, sans fête', () async {
    // Entre la purge et l'entrée de B, des faits VIDES ouvraient le journal :
    // la première lecture de B passait pour une suite, et chaque médaille de
    // son passé se célébrait comme fraîchement gagnée.
    await aliceSurSesReglages();
    await puisBruno();

    final deB = await recompenses();
    expect(deB.map((e) => e.reward.id), contains('discipline-10'));
    expect(deB.where((e) => e.isNew), isEmpty);
  });

  test('ses réglages, son code et son matériel restent les siens', () async {
    await aliceSurSesReglages();
    await puisBruno();

    expect(await container.read(notificationPreferencesProvider.future), {
      NotificationCategory.friendRequests: true,
    });
    expect(await container.read(myFriendCodeProvider.future), 'BRUNO234');
    expect(
      (await container.read(trainingProfileProvider.future)).equipmentSlugs,
      isEmpty,
    );
  });

  test('un premier échec chez B ne ressuscite pas A', () async {
    // A a lu ces caches PUIS quitté les écrans qui les montrent : plus rien
    // ne les écoute à la déconnexion, donc rien ne les relit sans session,
    // et ils gardent la valeur de A. B entre, le réseau tombe avant sa
    // première lecture : Riverpod garde la valeur précédente à travers
    // l'échec — c'était celle de A.
    await session().restore();
    await container.read(lifetimeStatsProvider.future);
    await container.read(personalRecordsProvider.future);
    await container.read(notificationPreferencesProvider.future);
    await container.read(myFriendCodeProvider.future);
    await container.read(trainingProfileProvider.future);
    await puisBruno();
    serveur.horsLigne = true;
    for (final cache in <ProviderListenable<Object?>>[
      lifetimeStatsProvider,
      personalRecordsProvider,
      notificationPreferencesProvider,
      myFriendCodeProvider,
      trainingProfileProvider,
    ]) {
      container.read(cache);
    }
    await pumpEventQueue();

    expect(
      container.read(lifetimeStatsProvider).valueOrNull?.completedSessions,
      isNot(200),
    );
    expect(container.read(personalRecordsProvider).valueOrNull, isEmpty);
    expect(
      container.read(notificationPreferencesProvider).valueOrNull,
      isNot(containsPair(NotificationCategory.friendRequests, false)),
    );
    expect(container.read(myFriendCodeProvider).valueOrNull, isNot('ALICE234'));
    expect(
      container.read(trainingProfileProvider).valueOrNull?.equipmentSlugs,
      isNot(contains('barre')),
    );
    expect(container.read(rewardFactsProvider)?.completedSessions, isNot(200));
  });

  test(
    'une relecture ratée hors ligne garde la valeur du MÊME compte',
    () async {
      // Le revers à ne pas payer : à la salle, sans réseau, la clôture d'une
      // séance relit les records et le profil relit les compteurs. L'échec
      // garde la valeur précédente, qui est bien celle de la personne : ses
      // médailles ne doivent pas disparaître le temps de retrouver le réseau.
      await aliceSurSesReglages();

      serveur.horsLigne = true;
      container
        ..invalidate(lifetimeStatsProvider)
        ..invalidate(personalRecordsProvider);
      await pumpEventQueue();

      expect(container.read(lifetimeStatsProvider).hasError, isTrue);
      expect(container.read(rewardFactsProvider)?.completedSessions, 200);
      expect(
        (await recompenses()).map((e) => e.reward.id),
        containsAll(medaillesDeA),
      );
    },
  );
}

/// Le serveur, qui répond pour le compte de la session EN COURS au moment
/// de l'appel — et refuse sans session, comme le vrai.
class _Serveur {
  _Serveur(this._auth) {
    progres = _Progres(this);
    communaute = _Communaute(this);
    reglages = _Reglages(this);
    profil = _Profil(this);
  }

  final FakeAuthRepository _auth;
  bool horsLigne = false;

  /// Les appels reçus SANS session : un cache de compte n'en fait aucun.
  int appelsSansSession = 0;

  late final _Progres progres;
  late final _Communaute communaute;
  late final _Reglages reglages;
  late final _Profil profil;

  /// Vrai pour A, faux pour B ; jette hors ligne ou sans session.
  bool estAlice() {
    if (horsLigne) throw const NetworkException('Hors ligne');
    if (!_auth.storedSession) {
      appelsSansSession++;
      throw const UnauthorizedException('Aucun jeton', statusCode: 401);
    }
    return _auth.user.id == 'user-a';
  }

  String compte() {
    estAlice();
    return _auth.user.id;
  }
}

class _Progres extends FakeProgressRepository {
  _Progres(this._serveur);

  final _Serveur _serveur;
  final Map<String, Set<String>> poussesPar = {};

  @override
  Future<LifetimeStats> lifetimeStats() async => LifetimeStats(
    completedSessions: _serveur.estAlice() ? 200 : 12,
    weeks: const [],
  );

  @override
  Future<List<PersonalRecordEntry>> records() async => _serveur.estAlice()
      ? [
          for (final exercice in ['Squat', 'Soulevé', 'Développé', 'Rowing'])
            recordOf(exercice, PersonalRecordType.maxWeight, 100),
          recordOf('Tractions', PersonalRecordType.maxReps, 15),
        ]
      : const [];

  @override
  Future<void> pushMilestones(Map<String, DateTime> rewards) async {
    (poussesPar[_serveur.compte()] ??= {}).addAll(rewards.keys);
  }
}

class _Communaute extends FakeCommunityRepository {
  _Communaute(this._serveur);

  final _Serveur _serveur;

  @override
  Future<String> myFriendCode() async =>
      _serveur.estAlice() ? 'ALICE234' : 'BRUNO234';
}

class _Reglages extends InMemoryDeviceTokenRepository {
  _Reglages(this._serveur);

  final _Serveur _serveur;

  @override
  Future<Map<NotificationCategory, bool>> preferences() async =>
      _serveur.estAlice()
      ? {NotificationCategory.friendRequests: false}
      : {NotificationCategory.friendRequests: true};
}

class _Profil extends FakeTrainingProfileRepository {
  _Profil(this._serveur);

  final _Serveur _serveur;

  @override
  Future<TrainingProfile> fetch() async => TrainingProfile(
    goal: null,
    experience: null,
    weeklySessionsTarget: null,
    sessionMinutesTarget: null,
    equipmentSlugs: _serveur.estAlice() ? const ['barre'] : const [],
  );
}
