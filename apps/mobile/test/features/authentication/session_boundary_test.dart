import 'dart:async';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/api/dio_client.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/database/local_account_switch.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:carlys_mobile/features/notifications/data/repositories/device_token_repository_impl.dart';
import 'package:carlys_mobile/features/notifications/data/services/firebase_push_messenger.dart';
import 'package:carlys_mobile/features/notifications/presentation/controllers/push_registration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_local_account_switch.dart';
import '../../support/fake_push_messenger.dart';
import '../../support/noop_local_account_purge.dart';
import '../notifications/push_registration_test.dart'
    show FakeDeviceTokenRepository, options;

/// CE QUI NE DOIT PAS TRAVERSER LA FRONTIÈRE D'UNE SESSION : le jeton push
/// du compte parti, et un profil revenu du serveur après coup.
void main() {
  late FakeAuthRepository auth;
  late FakePushMessenger messenger;
  late FakeDeviceTokenRepository tokens;
  late ProviderContainer container;

  const bruno = AuthUser(
    id: 'user-b',
    email: 'bruno@example.com',
    displayName: 'Bruno',
    emailVerified: true,
    locale: 'fr',
    timezone: 'Europe/Paris',
  );

  setUp(() {
    auth = FakeAuthRepository(storedSession: true);
    messenger = FakePushMessenger();
    tokens = FakeDeviceTokenRepository();
    container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
            push: options,
          ),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        localAccountPurgeProvider.overrideWithValue(NoopLocalAccountPurge()),
        localAccountSwitchProvider.overrideWithValue(FakeLocalAccountSwitch()),
        pushMessengerProvider.overrideWithValue(messenger),
        deviceTokenRepositoryProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(messenger.close);
  });

  AuthState etat() => container.read(authControllerProvider);

  group('session EXPIRÉE, puis un autre compte', () {
    test('le compte suivant est enregistré pour les notifications', () async {
      // LE SCÉNARIO DE L'AUDIT. A ouvre l'application : son jeton est
      // enregistré. Sa session expire (trente jours, ou révoquée depuis un
      // autre appareil), et B se connecte sans relancer l'application.
      // `_started` restait vrai : B n'était jamais enregistré, et le jeton,
      // resté au nom de A, affichait chez B les notifications de A.
      final controller = container.read(authControllerProvider.notifier);
      await controller.restore();
      container.read(pushRegistrationProvider).ensureStarted();
      await pumpEventQueue();
      expect(tokens.registered.map((entry) => entry.$1), ['jeton-1']);

      container.read(tokenRefresherProvider).onSessionExpired!();
      await pumpEventQueue();
      expect(etat(), isA<AuthUnauthenticated>());
      // Le jeton de A est effacé chez FCM : il ne sert plus à personne.
      expect(messenger.deleteCalls, 1);

      auth.user = bruno;
      messenger.token = 'jeton-de-bruno';
      await controller.login(email: bruno.email, password: 'x');
      container.read(pushRegistrationProvider).ensureStarted();
      await pumpEventQueue();

      expect(tokens.registered.map((entry) => entry.$1), [
        'jeton-1',
        'jeton-de-bruno',
      ]);
    });
  });

  group('profil rechargé', () {
    test('une réponse revenue après la déconnexion ne rallume rien', () async {
      // Choisir un objectif ou un style de Mentor recharge le profil. La
      // réponse tarde, la personne se déconnecte entre-temps : l'état
      // repassait à « connecté », sur une base purgée et sans jeton.
      final controller = container.read(authControllerProvider.notifier);
      await controller.restore();
      final gate = Completer<void>();
      auth.meGate = gate;

      final rechargement = controller.refreshProfile();
      await controller.logout();
      expect(etat(), isA<AuthUnauthenticated>());

      gate.complete();
      await rechargement;

      expect(etat(), isA<AuthUnauthenticated>());
    });

    test('ni l’identité de A chez B', () async {
      final controller = container.read(authControllerProvider.notifier);
      await controller.restore();
      final gate = Completer<void>();
      auth.meGate = gate;

      final rechargement = controller.refreshProfile();
      await controller.logout();
      auth
        ..meGate = null
        ..user = bruno;
      await controller.login(email: bruno.email, password: 'x');

      gate.complete();
      await rechargement;

      expect((etat() as AuthAuthenticated).user, bruno);
    });

    test('un profil encore inconnu (hors ligne) est bien complété', () async {
      // Restauration hors ligne : la session est ouverte sans profil. Le
      // rechargement suivant appartient forcément à cette session-là.
      final controller = container.read(authControllerProvider.notifier);
      auth.meFailure = const NetworkException('hors ligne (voulu)');
      await controller.restore();
      expect((etat() as AuthAuthenticated).user, isNull);
      auth.meFailure = null;

      await controller.refreshProfile();

      expect((etat() as AuthAuthenticated).user?.id, fakeUser.id);
    });
  });
}
