import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/api/dio_client.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/noop_local_account_purge.dart';

/// Purge qui échoue : la déconnexion doit quand même aboutir.
class _FailingPurge implements LocalAccountPurge {
  _FailingPurge(this._failure);

  final Object _failure;

  @override
  Future<void> run() async => throw _failure;
}

/// Le contrôleur de session purge l'état local du compte aux deux sorties
/// possibles, et seulement là : déconnexion volontaire et expiration de
/// session. L'interface ne bascule qu'APRÈS, pour qu'aucun compte ne se
/// connecte sur les données d'un autre.
void main() {
  late FakeAuthRepository auth;
  late NoopLocalAccountPurge purge;
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
    ],
  );

  setUp(() {
    auth = FakeAuthRepository(storedSession: true);
    purge = NoopLocalAccountPurge();
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

  test('l’expiration de session purge aussi', () async {
    final controller = container.read(authControllerProvider.notifier);
    await controller.restore();

    container.read(tokenRefresherProvider).onSessionExpired!();
    await pumpEventQueue();

    expect(purge.runs, 1);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());

    // Déjà déconnecté : une seconde expiration ne purge pas deux fois.
    container.read(tokenRefresherProvider).onSessionExpired!();
    await pumpEventQueue();
    expect(purge.runs, 1);
  });

  test('se connecter ne purge rien : la purge est à la sortie', () async {
    final controller = container.read(authControllerProvider.notifier);
    await controller.login(email: 'camille@example.com', password: 'x');

    expect(purge.runs, 0);
    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
  });

  /// Une purge en échec ne retient jamais la déconnexion, quelle que soit la
  /// sortie et quel que soit le TYPE de l'échec. `StateError` n'est pas un
  /// cas d'école : Drift et Riverpod signalent ainsi une base fermée ou un
  /// conteneur disposé, et c'est exactement ce que deux sorties concurrentes
  /// (un 401 du renouvellement pendant une déconnexion volontaire) produisent.
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

    test('une purge qui jette une $kind ne retient pas l’expiration', () async {
      container.dispose();
      container = build(_FailingPurge(failure));
      final controller = container.read(authControllerProvider.notifier);
      await controller.restore();

      container.read(tokenRefresherProvider).onSessionExpired!();
      await pumpEventQueue();

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    });
  }
}
