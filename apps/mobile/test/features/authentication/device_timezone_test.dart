import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/database/local_account_switch.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/device_timezone_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_local_account_switch.dart';
import '../../support/noop_local_account_purge.dart';

/// LE FUSEAU DE L'APPAREIL DOIT ARRIVER AU SERVEUR.
///
/// C'est lui qui découpe les jours des séries de constance que les amis
/// voient. Tant que personne ne l'envoyait, tout le monde restait au défaut
/// du serveur : une séance du dimanche 19 h à Montréal comptait pour le lundi
/// à Paris, et la série se décalait d'un jour pour ceux qui la regardaient.
///
/// La référence est la valeur RENDUE PAR LE SERVEUR, pas une trace locale :
/// elle est juste par construction et appartient au compte connecté.
void main() {
  late FakeAuthRepository auth;

  const montreal = 'America/Montreal';

  AuthUser userAt(String timezone) => AuthUser(
    id: 'user-1',
    email: 'camille@example.com',
    displayName: 'Camille',
    emailVerified: true,
    locale: 'fr',
    timezone: timezone,
  );

  setUp(() {
    auth = FakeAuthRepository(storedSession: true);
  });

  ProviderContainer containerWith(DeviceTimezoneReader reader) {
    final container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        localAccountPurgeProvider.overrideWithValue(NoopLocalAccountPurge()),
        // Entrer dans un compte réclame l'appareil : inerte ici, sinon la
        // réclamation lirait les vraies préférences et la restauration
        // s'arrêterait avant d'avoir déclaré quoi que ce soit.
        localAccountSwitchProvider.overrideWithValue(FakeLocalAccountSwitch()),
        deviceTimezoneReaderProvider.overrideWithValue(reader),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('réconciliation', () {
    test(
      'fuseau différent : il part au serveur, et l’utilisateur revient',
      () async {
        auth.user = userAt('Europe/Paris');
        final container = containerWith(() async => montreal);

        final updated = await container
            .read(deviceTimezoneSyncProvider)
            .reconcile(auth.user);

        expect(auth.timezonesSent, [montreal]);
        expect(updated?.timezone, montreal);
      },
    );

    test('fuseau identique : rien ne part', () async {
      final container = containerWith(() async => 'Europe/Paris');

      final updated = await container
          .read(deviceTimezoneSyncProvider)
          .reconcile(userAt('Europe/Paris'));

      expect(auth.timezonesSent, isEmpty);
      expect(updated, isNull);
    });

    test(
      'fuseau illisible (greffon absent) : rien ne part, rien ne casse',
      () async {
        final container = containerWith(
          () async => throw Exception('MissingPluginException'),
        );

        final updated = await container
            .read(deviceTimezoneSyncProvider)
            .reconcile(userAt('Europe/Paris'));

        expect(auth.timezonesSent, isEmpty);
        expect(updated, isNull);
      },
    );

    test(
      'hors ligne : l’échec est absorbé, l’appel a bien été tenté',
      () async {
        auth.timezoneFailure = const NetworkException('Serveur injoignable');
        final container = containerWith(() async => montreal);

        final updated = await container
            .read(deviceTimezoneSyncProvider)
            .reconcile(userAt('Europe/Paris'));

        expect(auth.timezonesSent, [montreal]);
        expect(updated, isNull);
      },
    );
  });

  group('branchement sur le contrôleur de session', () {
    test('premier démarrage : le fuseau part avec la restauration', () async {
      auth.user = userAt('Europe/Paris');
      final container = containerWith(() async => montreal);

      await container.read(authControllerProvider.notifier).restore();
      // La déclaration est lancée SANS être attendue : une session ne se
      // joue pas sur un fuseau. On laisse donc tourner la file d'événements.
      await pumpEventQueue();

      expect(auth.timezonesSent, [montreal]);
      final state = container.read(authControllerProvider);
      expect((state as AuthAuthenticated).user?.timezone, montreal);
    });

    test('démarrage suivant : rien ne repart, le serveur sait déjà', () async {
      auth.user = userAt(montreal);
      final container = containerWith(() async => montreal);

      await container.read(authControllerProvider.notifier).restore();
      // La déclaration est lancée SANS être attendue : une session ne se
      // joue pas sur un fuseau. On laisse donc tourner la file d'événements.
      await pumpEventQueue();

      expect(auth.timezonesSent, isEmpty);
    });

    test(
      'inscription : le compte neuf ne reste pas au fuseau par défaut',
      () async {
        // Un compte tout juste créé porte le défaut du serveur.
        auth.user = userAt('Europe/Paris');
        final container = containerWith(() async => montreal);

        await container
            .read(authControllerProvider.notifier)
            .register(
              email: 'camille@example.com',
              password: 'mot-de-passe-solide',
              displayName: 'Camille',
            );
        await pumpEventQueue();

        expect(auth.timezonesSent, [montreal]);
      },
    );

    test('connexion : le fuseau est réaligné si l’appareil a bougé', () async {
      auth.user = userAt('Europe/Paris');
      final container = containerWith(() async => montreal);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'camille@example.com', password: 'x');
      await pumpEventQueue();

      expect(auth.timezonesSent, [montreal]);
    });

    test('une déclaration qui échoue ne retient pas la connexion', () async {
      auth.user = userAt('Europe/Paris');
      auth.timezoneFailure = const NetworkException('Serveur injoignable');
      final container = containerWith(() async => montreal);

      await container
          .read(authControllerProvider.notifier)
          .login(email: 'camille@example.com', password: 'x');

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    });
  });
}
