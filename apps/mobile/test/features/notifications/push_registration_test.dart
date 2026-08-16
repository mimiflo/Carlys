import 'dart:async';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:carlys_mobile/features/notifications/domain/services/push_messenger.dart';
import 'package:carlys_mobile/features/notifications/presentation/controllers/push_registration.dart';
import 'package:flutter_test/flutter_test.dart';

const options = FirebasePushOptions(
  apiKey: 'cle-de-test',
  appId: '1:000000000000:android:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'carlys-test',
);

AppEnvironment environment({AppFlavor flavor = AppFlavor.development}) =>
    AppEnvironment(
      flavor: flavor,
      apiBaseUrl: 'http://localhost:3000',
      push: options,
    );

class FakePushMessenger implements PushMessenger {
  FakePushMessenger({this.token = 'jeton-1'});

  /// Jeton rendu par [obtainToken] — null simule une permission refusée.
  String? token;
  int obtainCalls = 0;
  int deleteCalls = 0;
  final StreamController<String> refreshes = StreamController.broadcast();
  final StreamController<PushNotice> notices = StreamController.broadcast();

  @override
  Future<String?> obtainToken(FirebasePushOptions options) async {
    obtainCalls += 1;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Stream<PushNotice> get onForegroundMessage => notices.stream;

  @override
  Future<void> deleteToken() async {
    deleteCalls += 1;
  }
}

class FakeDeviceTokenRepository implements DeviceTokenRepository {
  bool failRegister = false;
  final List<(String, DevicePlatform)> registered = [];
  final List<String> unregistered = [];

  @override
  Future<void> register({
    required String token,
    required DevicePlatform platform,
  }) async {
    if (failRegister) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
    registered.add((token, platform));
  }

  @override
  Future<void> unregister(String token) async {
    unregistered.add(token);
  }

  /// Préférences en mémoire : absence de clé = accepté, comme le serveur.
  final Map<NotificationCategory, bool> prefs = {};

  @override
  Future<Map<NotificationCategory, bool>> preferences() async => prefs;

  @override
  Future<void> setPreference(
    NotificationCategory category, {
    required bool enabled,
  }) async {
    prefs[category] = enabled;
  }
}

(PushRegistration, FakePushMessenger, FakeDeviceTokenRepository) build({
  AppEnvironment? env,
}) {
  final messenger = FakePushMessenger();
  final repository = FakeDeviceTokenRepository();
  final registration = PushRegistration(
    environment: env ?? environment(),
    messenger: messenger,
    repository: repository,
  );
  return (registration, messenger, repository);
}

void main() {
  test('sans configuration Firebase : no-op assumé, rien n’est touché',
      () async {
    final messenger = FakePushMessenger();
    final repository = FakeDeviceTokenRepository();
    PushRegistration(
      environment: const AppEnvironment(
        flavor: AppFlavor.development,
        apiBaseUrl: 'http://localhost:3000',
      ),
      messenger: messenger,
      repository: repository,
    ).ensureStarted();
    await pumpEventQueue();

    expect(messenger.obtainCalls, 0);
    expect(repository.registered, isEmpty);
  });

  test('en démo : no-op même si la configuration est présente', () async {
    final (registration, messenger, _) =
        build(env: environment(flavor: AppFlavor.demo));
    registration.ensureStarted();
    await pumpEventQueue();

    expect(messenger.obtainCalls, 0);
  });

  test('configuré : le jeton est obtenu puis enregistré au serveur', () async {
    final (registration, _, repository) = build();
    registration
      ..ensureStarted()
      // Démarrer deux fois ne demande pas deux fois la permission.
      ..ensureStarted();
    await pumpEventQueue();

    expect(repository.registered, [('jeton-1', DevicePlatform.android)]);
    expect(registration.registeredToken, 'jeton-1');
  });

  test('permission refusée : choix respecté, aucun envoi au serveur', () async {
    final (registration, messenger, repository) = build();
    messenger.token = null;
    registration.ensureStarted();
    await pumpEventQueue();

    expect(messenger.obtainCalls, 1);
    expect(repository.registered, isEmpty);
    expect(registration.registeredToken, isNull);
  });

  test('un jeton rafraîchi par FCM est ré-enregistré', () async {
    final (registration, messenger, repository) = build();
    registration.ensureStarted();
    await pumpEventQueue();

    messenger.refreshes.add('jeton-2');
    await pumpEventQueue();

    expect(repository.registered.last, ('jeton-2', DevicePlatform.android));
    expect(registration.registeredToken, 'jeton-2');
  });

  test('serveur injoignable : rien ne casse, le jeton reste non enregistré',
      () async {
    final (registration, _, repository) = build();
    repository.failRegister = true;
    registration.ensureStarted();
    await pumpEventQueue();

    expect(registration.registeredToken, isNull);
  });

  test('déconnexion : oubli côté serveur PUIS côté appareil', () async {
    final (registration, messenger, repository) = build();
    registration.ensureStarted();
    await pumpEventQueue();

    await registration.forgetDevice();

    expect(repository.unregistered, ['jeton-1']);
    expect(messenger.deleteCalls, 1);
    expect(registration.registeredToken, isNull);

    // Rejouer l'oubli est silencieux — plus rien à oublier.
    await registration.forgetDevice();
    expect(repository.unregistered, hasLength(1));
  });

  test('déconnexion sans enregistrement préalable : no-op', () async {
    final (registration, messenger, repository) = build();

    await registration.forgetDevice();

    expect(repository.unregistered, isEmpty);
    expect(messenger.deleteCalls, 0);
  });
}
