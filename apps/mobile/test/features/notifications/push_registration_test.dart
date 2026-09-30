import 'dart:async';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:carlys_mobile/features/notifications/presentation/providers/push_registration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_push_messenger.dart';

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

class FakeDeviceTokenRepository implements DeviceTokenRepository {
  bool failRegister = false;
  final List<(String, DevicePlatform)> registered = [];
  final List<String> unregistered = [];

  /// Retient la réponse de l'enregistrement : la session peut expirer
  /// pendant l'aller-retour.
  Completer<void>? registerGate;

  @override
  Future<void> register({
    required String token,
    required DevicePlatform platform,
  }) async {
    await registerGate?.future;
    if (failRegister) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
    registered.add((token, platform));
  }

  /// Le désenregistrement échoue (hors ligne) : l'appareil doit oublier
  /// quand même.
  bool failUnregister = false;

  @override
  Future<void> unregister(String token) async {
    if (failUnregister) {
      throw const NetworkException('hors ligne (voulu par le test)');
    }
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
  test(
    'sans configuration Firebase : no-op assumé, rien n’est touché',
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
    },
  );

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

  test(
    'serveur injoignable : rien ne casse, le jeton reste non enregistré',
    () async {
      final (registration, _, repository) = build();
      repository.failRegister = true;
      registration.ensureStarted();
      await pumpEventQueue();

      expect(registration.registeredToken, isNull);
    },
  );

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

  test('déconnexion : le compte SUIVANT est bien réenregistré', () async {
    // CE QUE CE TEST PROTÈGE. `pushRegistrationProvider` n'est pas
    // auto-disposé : le MÊME objet sert au compte suivant. `forgetDevice`
    // effaçait le jeton sans remettre `_started` à faux, donc
    // `ensureStarted()` ressortait aussitôt et plus aucun appareil n'était
    // enregistré : la personne suivante ne recevait aucune notification
    // jusqu'au redémarrage de l'application.
    final (registration, messenger, repository) = build();
    registration.ensureStarted();
    await pumpEventQueue();
    expect(repository.registered, hasLength(1));

    await registration.forgetDevice();

    // Le compte suivant ouvre l'application : tout doit repartir.
    messenger.token = 'jeton-du-suivant';
    registration.ensureStarted();
    await pumpEventQueue();

    expect(repository.registered.last, (
      'jeton-du-suivant',
      DevicePlatform.android,
    ));
    expect(registration.registeredToken, 'jeton-du-suivant');
  });

  test(
    'déconnexion : un jeton rafraîchi ne s’enregistre plus sous la session suivante',
    () async {
      // L'abonnement au rafraîchissement appartenait au compte parti : laissé
      // vivant, un renouvellement FCM enregistrait son jeton sous la session
      // d'après.
      final (registration, messenger, repository) = build();
      registration.ensureStarted();
      await pumpEventQueue();

      await registration.forgetDevice();
      final apresOubli = repository.registered.length;

      messenger.refreshes.add('jeton-fantome');
      await pumpEventQueue();

      expect(repository.registered, hasLength(apresOubli));
    },
  );

  test('déconnexion sans enregistrement préalable : rien au serveur, le '
      'jeton de l’appareil part quand même', () async {
    // Ce lancement n'a rien enregistré (hors ligne, ou déconnexion avant
    // l'accueil), mais l'appareil a un jeton, que le serveur peut tenir
    // d'un lancement plus ancien : on ne peut pas le désenregistrer sans le
    // connaître, on peut l'effacer chez FCM.
    final (registration, messenger, repository) = build();

    await registration.forgetDevice();

    expect(repository.unregistered, isEmpty);
    expect(messenger.deleteCalls, 1);
  });

  test(
    'déconnexion hors ligne : le jeton de l’appareil part quand même',
    () async {
      // Le désenregistrement échoue sans réseau : l'effacement chez FCM, lui,
      // ne dépend pas du serveur, et c'est lui qui coupe l'arrivée.
      final (registration, messenger, repository) = build();
      repository.failUnregister = true;
      registration.ensureStarted();
      await pumpEventQueue();

      await registration.forgetDevice();

      expect(messenger.deleteCalls, 1);
      expect(registration.registeredToken, isNull);
    },
  );

  test('sans configuration Firebase, l’oubli ne touche pas au SDK', () async {
    final messenger = FakePushMessenger();
    final registration = PushRegistration(
      environment: const AppEnvironment(
        flavor: AppFlavor.development,
        apiBaseUrl: 'http://localhost:3000',
      ),
      messenger: messenger,
      repository: FakeDeviceTokenRepository(),
    );

    await registration.forgetDevice();
    await registration.forgetLocally();

    expect(messenger.deleteCalls, 0);
  });

  group('compte SUPPRIMÉ', () {
    test('rien n’est demandé au serveur : le compte n’existe plus', () async {
      // Ses jetons d'appareil sont partis avec lui. Un désenregistrement
      // partirait sur une session déjà invalide, pour rien.
      final (registration, messenger, repository) = build();
      registration.ensureStarted();
      await pumpEventQueue();

      await registration.forgetLocally();

      expect(repository.unregistered, isEmpty);
      // Le jeton local, lui, est bien effacé : celui d'avant est mort.
      expect(messenger.deleteCalls, 1);
      expect(registration.registeredToken, isNull);
    });

    test('le compte SUIVANT reçoit à nouveau ses notifications', () async {
      // CE QUE CE TEST PROTÈGE. Ce chemin n'appelait RIEN : `_started`
      // restait vrai sur l'objet, qui survit à la bascule de compte, et
      // `ensureStarted()` ressortait aussitôt pour la personne suivante —
      // aucune notification jusqu'au redémarrage de l'application.
      final (registration, messenger, repository) = build();
      registration.ensureStarted();
      await pumpEventQueue();

      await registration.forgetLocally();

      messenger.token = 'jeton-du-suivant';
      registration.ensureStarted();
      await pumpEventQueue();

      expect(registration.registeredToken, 'jeton-du-suivant');
      expect(repository.registered.last, (
        'jeton-du-suivant',
        DevicePlatform.android,
      ));
    });

    test('un jeton rafraîchi ne s’enregistre plus sous la suite', () async {
      final (registration, messenger, repository) = build();
      registration.ensureStarted();
      await pumpEventQueue();

      await registration.forgetLocally();
      final apres = repository.registered.length;

      messenger.refreshes.add('jeton-fantome');
      await pumpEventQueue();

      expect(repository.registered, hasLength(apres));
    });
  });
  group('session EXPIRÉE', () {
    test('démarrage à froid : expirée AVANT tout enregistrement, le jeton '
        'de l’appareil part quand même', () async {
      // LE DÉMARRAGE À FROID APRÈS TRENTE JOURS, dans son VRAI ordre. La
      // restauration ouvre la session, `me()` rencontre le 401, le
      // renouvellement échoue : la session expire pendant l'écran de
      // démarrage, avant que l'accueil n'ait rien démarré. Ce processus ne
      // connaît donc aucun jeton — mais l'appareil en a un, et le serveur
      // le tient d'un enregistrement ancien (un jeton d'avant le
      // rattachement aux sessions n'expire avec aucune). Sans l'effacer chez
      // FCM, les notifications du compte parti continuaient d'arriver.
      final (registration, messenger, repository) = build();

      await registration.forgetLocally();

      expect(messenger.deleteCalls, 1);
      expect(repository.registered, isEmpty);

      // Le compte suivant entre : un jeton NEUF, enregistré à son nom.
      messenger.token = 'jeton-du-suivant';
      registration.ensureStarted();
      await pumpEventQueue();
      expect(repository.registered.single.$1, 'jeton-du-suivant');
    });

    test(
      'un jeton demandé mais jamais enregistré est effacé quand même',
      () async {
        // La session expire PENDANT l'enregistrement : son envoi est
        // justement la requête qui rencontre le 401. `registeredToken`
        // reste nul, alors que le serveur tient ce jeton d'un enregistrement
        // plus ancien, au nom du compte parti.
        final (registration, messenger, repository) = build();
        repository.failRegister = true;
        registration.ensureStarted();
        await pumpEventQueue();
        expect(registration.registeredToken, isNull);

        await registration.forgetLocally();

        expect(messenger.deleteCalls, 1);
      },
    );

    test('un jeton rendu APRÈS l’oubli ne part pas au serveur', () async {
      // FCM rend le jeton lentement (premier lancement, réseau lent), et la
      // session expire entre-temps. Ce jeton est celui que l'oubli efface :
      // l'enregistrer le poserait mort au serveur, voire sous le compte
      // suivant s'il est déjà entré.
      final (registration, messenger, repository) = build();
      final gate = Completer<void>();
      messenger.obtainGate = gate;
      registration.ensureStarted();
      await pumpEventQueue();

      await registration.forgetLocally();
      gate.complete();
      await pumpEventQueue();

      expect(repository.registered, isEmpty);
    });

    test('un enregistrement EN VOL ne ressuscite rien après l’oubli', () async {
      // La session expire pendant l'aller-retour de l'enregistrement. Sa
      // réponse, revenue après l'oubli, remettait le jeton en place et
      // rouvrait l'abonnement au rafraîchissement : un jeton renouvelé
      // s'enregistrait ensuite sous la session du compte suivant.
      final (registration, messenger, repository) = build();
      final gate = Completer<void>();
      repository.registerGate = gate;
      registration.ensureStarted();
      await pumpEventQueue();

      await registration.forgetLocally();
      gate.complete();
      await pumpEventQueue();

      expect(registration.registeredToken, isNull);
      final avant = repository.registered.length;
      messenger.refreshes.add('jeton-fantome');
      await pumpEventQueue();
      expect(repository.registered, hasLength(avant));
    });

    test('le compte suivant attend que l’ancien jeton soit effacé', () async {
      // Sans cette attente, le compte suivant pouvait obtenir le jeton même
      // qu'on était en train d'effacer, et l'enregistrer mort.
      final (registration, messenger, repository) = build();
      registration.ensureStarted();
      await pumpEventQueue();
      final gate = Completer<void>();
      messenger.deleteGate = gate;

      final oubli = registration.forgetLocally();
      messenger.token = 'jeton-du-suivant';
      registration.ensureStarted();
      await pumpEventQueue();
      expect(messenger.obtainCalls, 1, reason: 'effacement pas fini');

      gate.complete();
      await oubli;
      await pumpEventQueue();

      expect(messenger.obtainCalls, 2);
      expect(registration.registeredToken, 'jeton-du-suivant');
      expect(repository.registered.last.$1, 'jeton-du-suivant');
    });
  });
}
