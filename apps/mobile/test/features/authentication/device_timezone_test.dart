import 'dart:async';

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

    test(
      'enveloppe inattendue : la FormatException est absorbée elle aussi',
      () async {
        // Le dépôt ne convertit QUE les `DioException` : une réponse mal
        // formée traverse la couche données sous la forme d'une
        // `FormatException`, qui n'est pas une `AppException`. Filtrée sur
        // `AppException`, elle s'échappait d'un appel lancé sans attendre et
        // finissait en erreur non capturée dans le zone guard de bootstrap.
        auth.timezoneFailure = const FormatException(
          'Enveloppe de réponse inattendue',
        );
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

    test('une déclaration qui ne répond JAMAIS ne retient pas la '
        'connexion', () async {
      // Le caractère non bloquant est TOUT l'objet du choix : une panne ne le
      // prouve pas (l'échec est absorbé dans la même micro-tâche, donc un
      // `await` passerait le test à l'identique). Seule une dépendance qui ne
      // se termine pas distingue les deux — ici la lecture du fuseau, qui
      // passe par un canal de plateforme muet sur un bureau ou un banc de
      // test.
      auth.user = userAt('Europe/Paris');
      // Volontairement jamais complété : c'est un canal de plateforme muet.
      final mute = Completer<String>();
      final container = containerWith(() => mute.future);

      // Rendre la main EST l'assertion : si la connexion attendait la
      // déclaration, ce `await` ne finirait jamais et le test expirerait.
      await container
          .read(authControllerProvider.notifier)
          .login(email: 'camille@example.com', password: 'x');
      await pumpEventQueue();

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      // La lecture n'a jamais répondu : rien n'a pu partir.
      expect(auth.timezonesSent, isEmpty);
    });

    test(
      'un serveur qui ne répond JAMAIS ne retient pas la restauration',
      () async {
        // Même preuve, un cran plus loin : la lecture répond, c'est l'ENVOI qui
        // reste en l'air — le cas du réseau qui pend au lieu d'échouer.
        auth.user = userAt('Europe/Paris');
        auth.timezoneGate = Completer<void>();
        final container = containerWith(() async => montreal);

        await container.read(authControllerProvider.notifier).restore();
        await pumpEventQueue();

        expect(
          container.read(authControllerProvider),
          isA<AuthAuthenticated>(),
        );
        expect(auth.timezonesSent, [montreal]);
      },
    );

    test(
      'session fermée pendant l’aller-retour : rien ne se rallume',
      () async {
        // LE danger nommé par le constat : la réponse revient après coup. Si
        // elle écrit sans regarder, elle rallume une session que l'utilisateur
        // vient de fermer — l'application se rouvre sur un compte déconnecté.
        auth.user = userAt('Europe/Paris');
        final gate = Completer<void>();
        auth.timezoneGate = gate;
        final container = containerWith(() async => montreal);
        final controller = container.read(authControllerProvider.notifier);

        await controller.login(email: 'camille@example.com', password: 'x');
        await pumpEventQueue();
        // La déclaration est bien PARTIE : c'est ce départ-là qui reviendra.
        expect(auth.timezonesSent, [montreal]);

        await controller.logout();
        expect(
          container.read(authControllerProvider),
          isA<AuthUnauthenticated>(),
        );

        gate.complete();
        await pumpEventQueue();

        expect(
          container.read(authControllerProvider),
          isA<AuthUnauthenticated>(),
        );
      },
    );

    test(
      'compte changé pendant l’aller-retour : B n’est pas écrasé par A',
      () async {
        // La frontière de compte, celle que `LocalAccountSwitch` et la purge
        // locale défendent partout ailleurs. Une déclaration partie pour A,
        // revenue après que B s'est connecté sur le même téléphone, remettait
        // A dans l'état : le profil affichait le nom et l'adresse de quelqu'un
        // d'autre jusqu'au prochain `me()`.
        const alix = AuthUser(
          id: 'user-a',
          email: 'alix@example.com',
          displayName: 'Alix',
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
          // Déjà au bon fuseau : la connexion de B ne déclare rien, seule la
          // réponse de A est encore en l'air.
          timezone: montreal,
        );

        auth.user = alix;
        final gate = Completer<void>();
        auth.timezoneGate = gate;
        final container = containerWith(() async => montreal);
        final controller = container.read(authControllerProvider.notifier);

        await controller.login(email: 'alix@example.com', password: 'x');
        await pumpEventQueue();
        expect(auth.timezonesSent, [montreal]);

        // L'appareil change de mains.
        await controller.logout();
        auth.user = bruno;
        await controller.login(email: 'bruno@example.com', password: 'x');
        await pumpEventQueue();

        gate.complete();
        await pumpEventQueue();

        final state = container.read(authControllerProvider);
        expect((state as AuthAuthenticated).user, bruno);
      },
    );
  });
}
