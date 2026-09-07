import 'dart:convert';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/api/dio_client.dart';
import 'package:carlys_mobile/core/auth/token_storage.dart';
import 'package:carlys_mobile/core/database/app_database.dart';
import 'package:carlys_mobile/core/database/local_account_owner.dart';
import 'package:carlys_mobile/core/database/local_account_switch.dart';
import 'package:carlys_mobile/core/synchronization/sync_api.dart';
import 'package:carlys_mobile/core/synchronization/sync_engine.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:carlys_mobile/features/progression/data/reward_ledger.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_secure_storage.dart';
import '../../support/fake_sync_api.dart';
import '../../support/fake_workout_repository.dart';

/// Un compte tel que le dépôt d'authentification le rend.
AuthUser _accountOf(String id) => AuthUser(
  id: id,
  email: '$id@example.com',
  displayName: id,
  emailVerified: true,
  locale: 'fr',
  timezone: 'Europe/Paris',
);

/// Un JWT non signé : seul le claim `sub` est lu, pour un rangement local.
String _jwt(String subject) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode({'sub': subject})}.sig';
}

/// La purge est différée à la connexion d'un compte DIFFÉRENT.
///
/// L'expiration de session (401 au renouvellement, soit trente jours sans
/// ouvrir l'application) n'est pas un changement de compte : purger là
/// détruisait les séances, les séries et la file non synchronisées du MÊME
/// utilisateur. Ces tests défendent les trois cas : expiration, retour du
/// même compte, arrivée d'un autre.
void main() {
  late ProviderContainer container;
  late AppDatabase database;
  late FakeSyncApi api;
  late FakeAuthRepository auth;
  late FakeSecureStorage secure;

  final opened = <AppDatabase>[];
  final at = DateTime.utc(2026, 9, 1, 10);

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      LocalAccountOwner.key: 'user-a',
      RewardLedger.key: '{"premiere-seance":"2026-09-01T10:00:00.000Z"}',
    });
    opened.clear();
    api = FakeSyncApi();
    auth = FakeAuthRepository(storedSession: true, user: _accountOf('user-a'));
    // Le jeton du trousseau porte le même compte : en production c'est la
    // source unique, et le moteur de synchronisation y lit son propriétaire.
    secure = FakeSecureStorage();
    secure.values['carlys_access_token'] = _jwt('user-a');
    container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(NativeDatabase.memory());
          opened.add(db);
          return db;
        }),
        syncApiProvider.overrideWithValue(api),
        syncLifecycleProvider.overrideWith((ref) => NoopSyncLifecycle()),
        appRestoreProvider.overrideWith((ref) => NoopAppRestore()),
        authRepositoryProvider.overrideWithValue(auth),
        tokenStorageProvider.overrideWithValue(TokenStorage(secure)),
      ],
    );
    database = container.read(appDatabaseProvider);
    await _fillAccountOfA(database, at);
  });

  tearDown(() async {
    container.dispose();
    for (final db in opened) {
      await db.close();
    }
  });

  /// Ce que l'utilisateur a saisi hors ligne : une séance et l'opération qui
  /// attend de partir.
  Future<int> localRows() async =>
      (await database.select(database.localWorkoutSessions).get()).length +
      (await database.select(database.syncOperations).get()).length;

  test('l’expiration de session ne détruit rien', () async {
    // Trente jours sans ouvrir l'application : le renouvellement répond 401.
    // C'est le MÊME utilisateur qui revient — ses séances, ses séries et sa
    // file doivent l'attendre.
    final controller = container.read(authControllerProvider.notifier);
    await controller.restore();
    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

    container.read(tokenRefresherProvider).onSessionExpired!();
    await pumpEventQueue();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    expect(await localRows(), 2);
    expect(identical(container.read(appDatabaseProvider), database), isTrue);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocalAccountOwner.key), 'user-a');
    expect(preferences.containsKey(RewardLedger.key), isTrue);
  });

  test('le même compte revient : rien n’est purgé, la file repart', () async {
    await container.read(localAccountSwitchProvider).claimDevice();

    expect(await localRows(), 2);
    expect(identical(container.read(appDatabaseProvider), database), isTrue);

    // Et l'opération en attente part enfin, sous son propre compte.
    await container.read(syncEngineProvider).syncNow();
    expect(api.log, ['session.create:seance-de-a']);
  });

  test('un compte différent : tout part AVANT le moindre drainage', () async {
    auth.user = _accountOf('user-b');

    await container.read(localAccountSwitchProvider).claimDevice();

    // La base de A est vidée, et une base neuve prend le relais.
    expect(await localRows(), 0);
    expect(opened, hasLength(2));
    final databaseAfter = container.read(appDatabaseProvider);
    expect(identical(databaseAfter, database), isFalse);
    expect(
      await databaseAfter.select(databaseAfter.syncOperations).get(),
      isEmpty,
    );
    // Rien de A ne peut plus partir : il n'y a plus rien à drainer.
    await container.read(syncEngineProvider).syncNow();
    expect(api.log, isEmpty);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey(RewardLedger.key), isFalse);
    expect(preferences.getString(LocalAccountOwner.key), 'user-b');
  });

  test('la connexion d’un autre compte purge, puis authentifie', () async {
    auth.user = _accountOf('user-b');
    final controller = container.read(authControllerProvider.notifier);

    await controller.login(email: 'basile@example.com', password: 'x');

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(await localRows(), 0);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocalAccountOwner.key), 'user-b');
  });

  test('appareil sans marqueur : rien à purger, le compte le pose', () async {
    // Cas de la mise à jour depuis une version qui n'écrivait pas encore le
    // propriétaire : le compte présent le pose au démarrage suivant, et
    // c'est lui qui protégera le changement de compte d'après.
    SharedPreferences.setMockInitialValues({});

    await container.read(localAccountSwitchProvider).claimDevice();

    expect(await localRows(), 2);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocalAccountOwner.key), 'user-a');
  });

  test('session illisible : rien n’est purgé, rien n’est retenu', () async {
    // Sur un doute, on ne détruit pas : la prochaine entrée tranchera.
    auth.storedSession = false;

    await container.read(localAccountSwitchProvider).claimDevice();

    expect(await localRows(), 2);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(LocalAccountOwner.key), 'user-a');
  });
}

/// L'appareil porte le travail hors ligne de A : une séance et l'opération
/// qui attend de partir sous son compte.
Future<void> _fillAccountOfA(AppDatabase db, DateTime at) async {
  await db
      .into(db.localWorkoutSessions)
      .insert(
        LocalWorkoutSessionsCompanion.insert(
          id: 'seance-de-a',
          status: 'IN_PROGRESS',
          startedAt: at,
        ),
      );
  await db
      .into(db.syncOperations)
      .insert(
        SyncOperationsCompanion.insert(
          id: 'op-1',
          entityType: 'session',
          entityId: 'seance-de-a',
          operationType: 'session.create',
          payload: jsonEncode({'id': 'seance-de-a'}),
          createdAt: at,
          idempotencyKey: 'seance-de-a',
          ownerUserId: const Value('user-a'),
        ),
      );
}
