import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/api/dio_client.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/database/local_account_switch.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_local_account_switch.dart';
import '../../support/noop_local_account_purge.dart';

/// Purge qui échoue : la déconnexion doit quand même aboutir.
class _FailingPurge implements LocalAccountPurge {
  _FailingPurge(this._failure);

  final Object _failure;

  @override
  Future<void> run() async => throw _failure;
}

/// Où le contrôleur de session efface l'état local du compte, et où il ne
/// l'efface surtout pas.
///
///  - déconnexion volontaire : purge immédiate, PUIS bascule de l'interface ;
///  - entrée dans un compte : l'appareil est réclamé AVANT la bascule, et la
///    purge n'a lieu que si le compte qui arrive n'est pas celui des données
///    présentes (`LocalAccountSwitch`) ;
///  - expiration de session : rien n'est effacé. C'est le même utilisateur,
///    sur son compte, revenu après trente jours ; ses séances et sa file
///    l'attendent.
void main() {
  late FakeAuthRepository auth;
  late NoopLocalAccountPurge purge;
  late FakeLocalAccountSwitch entry;
  late ProviderContainer container;

  ProviderContainer build(LocalAccountPurge purge) => ProviderContainer(
    overrides: [
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment(
          flavor: AppFlavor.development,
          apiBaseUrl: 'http://localhost:3000',
        ),
      ),
      authRepositoryProvider.overrideWithValue(auth),
      localAccountPurgeProvider.overrideWithValue(purge),
      localAccountSwitchProvider.overrideWithValue(entry),
    ],
  );

  setUp(() {
    auth = FakeAuthRepository(storedSession: true);
    purge = NoopLocalAccountPurge();
    entry = FakeLocalAccountSwitch();
    container = build(purge);
  });

  tearDown(() => container.dispose());

  test('la déconnexion purge, puis bascule', () async {
    final controller = container.read(authControllerProvider.notifier);
    await controller.restore();
    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

    await controller.logout();

    expect(auth.logoutCalls, 1);
    expect(purge.runs, 1);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('l’expiration de session ne purge RIEN', () async {
    // Le défaut réparé ici : l'expiration survient sur un 401 du
    // renouvellement, c'est-à-dire après trente jours sans ouvrir
    // l'application. Purger là détruisait les séances, les séries et les
    // opérations en file du MÊME utilisateur, sur SON compte.
    final controller = container.read(authControllerProvider.notifier);
    await controller.restore();

    container.read(tokenRefresherProvider).onSessionExpired!();
    await pumpEventQueue();

    expect(purge.runs, 0);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('se connecter réclame l’appareil avant de basculer', () async {
    final controller = container.read(authControllerProvider.notifier);
    await controller.login(email: 'camille@example.com', password: 'x');

    // C'est la réclamation, et elle seule, qui décide de purger : le même
    // compte qui revient ne perd rien.
    expect(entry.claims, 1);
    expect(purge.runs, 0);
    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
  });

  test('s’inscrire réclame aussi l’appareil', () async {
    final controller = container.read(authControllerProvider.notifier);
    await controller.register(
      email: 'basile@example.com',
      password: 'x',
      displayName: 'Basile',
    );

    expect(entry.claims, 1);
    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
  });

  test('une réclamation impossible fait échouer la connexion', () async {
    // Entrer quand même, ce serait ouvrir l'application du nouveau compte
    // sur les données de l'ancien : l'erreur remonte au formulaire.
    entry.failure = StateError('base verrouillée');
    final controller = container.read(authControllerProvider.notifier);

    await expectLater(
      controller.login(email: 'basile@example.com', password: 'x'),
      throwsStateError,
    );
    expect(
      container.read(authControllerProvider),
      isNot(isA<AuthAuthenticated>()),
    );
  });

  test('une réclamation impossible refuse la restauration', () async {
    // L'écran de démarrage appelle `restore()` sans attendre : l'échec ne
    // peut pas remonter, on refuse donc d'entrer.
    entry.failure = StateError('base verrouillée');
    final controller = container.read(authControllerProvider.notifier);

    await controller.restore();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  /// Une purge en échec ne retient jamais la déconnexion, quel que soit le
  /// TYPE de l'échec. `StateError` n'est pas un cas d'école : Drift et
  /// Riverpod signalent ainsi une base fermée ou un conteneur disposé, et
  /// c'est exactement ce que produisent deux sorties concurrentes (un 401 du
  /// renouvellement pendant une déconnexion volontaire).
  for (final failure in <Object>[
    Exception('base verrouillée'),
    StateError('Cannot operate on a closed database'),
  ]) {
    final kind = failure is Error ? 'Error' : 'Exception';

    test(
      'une purge qui jette une $kind ne retient pas la déconnexion',
      () async {
        container.dispose();
        container = build(_FailingPurge(failure));
        final controller = container.read(authControllerProvider.notifier);
        await controller.restore();

        await controller.logout();

        expect(
          container.read(authControllerProvider),
          isA<AuthUnauthenticated>(),
        );
      },
    );
  }
}
