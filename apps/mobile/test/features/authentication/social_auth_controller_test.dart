import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/database/local_account_switch.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/authentication/data/datasources/social_sign_in.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_provider.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/social_auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_local_account_switch.dart';
import '../../support/noop_local_account_purge.dart';

/// Les ISSUES du contrôleur de connexion sociale : ce que l'écran reçoit
/// pour chaque cause, message ET code. L'écran ne connaît que ces issues —
/// si le code n'y est pas, il n'est nulle part.
void main() {
  late FakeAuthRepository auth;
  late FakeLocalAccountSwitch entry;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    entry = FakeLocalAccountSwitch();
    container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        localAccountPurgeProvider.overrideWithValue(NoopLocalAccountPurge()),
        localAccountSwitchProvider.overrideWithValue(entry),
      ],
    );
    // Auto-disposé : sans auditeur, il disparaîtrait entre deux lectures.
    container.listen(socialAuthControllerProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  Future<SocialAuthOutcome> signIn([
    SocialProvider provider = SocialProvider.google,
  ]) => container.read(socialAuthControllerProvider.notifier).signIn(provider);

  /// L'échec rendu, ou un échec de test si l'issue n'en est pas un.
  Future<SocialAuthFailure> failure() async {
    final outcome = await signIn();
    expect(outcome, isA<SocialAuthFailed>());
    return (outcome as SocialAuthFailed).failure;
  }

  test('session ouverte : rien à dire', () async {
    expect(await signIn(), isA<SocialAuthSucceeded>());
  });

  test('feuille refermée : muet, sans code', () async {
    auth.socialCancelled = true;
    expect(await signIn(), isA<SocialAuthCancelled>());
  });

  test(
    'échec du SDK : le code de la passerelle, la phrase de l’obstacle',
    () async {
      auth.socialError = const SocialSignInUnavailable(
        SocialProvider.google,
        SocialSignInObstacle.echec,
        code: 'google-12500',
      );

      final rendu = await failure();

      expect(rendu.code, 'google-12500');
      expect(
        rendu.message,
        startsWith('Google n’a pas pu terminer la connexion'),
      );
      expect(rendu.codeLine, 'Code\u00A0: google-12500');
    },
  );

  test('limite de débit : http-429, avec sa référence', () async {
    auth.socialError = const ServerException(
      'ThrottlerException: Too Many Requests',
      statusCode: 429,
      requestId: 'abcdef01-2345',
      fromApi: true,
    );

    final rendu = await failure();

    expect(rendu.code, 'http-429');
    expect(rendu.codeLine, 'Code\u00A0: http-429 · réf.\u00A0abcdef01');
    expect(rendu.message, contains('Attends une minute'));
  });

  test('compte suspendu : SON message, http-401 et sa référence', () async {
    // Le cas RÉEL : `/auth/social` ne lève aucun 403. Un compte suspendu ou
    // désactivé est refusé en 401 par `refuserSiInactif`
    // (social-auth.service.ts), avec cette phrase. Avant : il tombait sur
    // « n’a pas abouti », le message du serveur était perdu.
    auth.socialError = const UnauthorizedException(
      'Connexion impossible avec ce compte.',
      statusCode: 401,
      requestId: '5e5e5e5e-0000',
      fromApi: true,
    );

    final rendu = await failure();

    expect(rendu.code, 'http-401');
    expect(rendu.message, 'Connexion impossible avec ce compte.');
    expect(rendu.codeLine, 'Code\u00A0: http-401 · réf.\u00A05e5e5e5e');
  });

  test('réclamation d’appareil refusée : appli-compte', () async {
    entry.failure = StateError('base verrouillée');

    final rendu = await failure();

    expect(rendu.code, 'appli-compte');
    expect(auth.logoutCalls, 1);
  });

  test('erreur imprévue : le filet garde un code', () async {
    auth.socialError = ArgumentError('imprévu');

    final rendu = await failure();

    expect(rendu.code, 'appli-inattendu');
    expect(
      rendu.message,
      'La connexion avec Google n’a pas abouti. Réessaie, ou utilise ton '
      'adresse e-mail.',
    );
  });

  test('après un échec, les boutons se réarment', () async {
    auth.socialError = const ServerException(
      'x',
      statusCode: 500,
      fromApi: true,
    );

    await signIn();

    expect(container.read(socialAuthControllerProvider), isNull);
  });
}
