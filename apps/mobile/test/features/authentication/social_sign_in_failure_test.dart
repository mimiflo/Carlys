import 'package:carlys_mobile/features/authentication/data/datasources/social_sign_in_failure.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_provider.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_sign_in_unavailable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// CE QUE CE FICHIER PROTÈGE : le CODE que la personne recopie quand le SDK
/// d'un fournisseur échoue, et la catégorie qui choisit sa phrase.
///
/// Les `PlatformException` ci-dessous ne sont pas inventées : codes et
/// messages sont ceux que produit `GoogleSignInPlugin.java`
/// (google_sign_in_android 6.2.1) — `errorCodeForStatus` pour le code,
/// `ApiException.toString()` pour le message (« com.google.android.gms.
/// common.api.ApiException: 12500: »), et les chaînes fixes de
/// `finishWithError` pour les autres chemins.
void main() {
  const apiException = 'com.google.android.gms.common.api.ApiException';

  PlatformException sdk(String code, String? message) =>
      PlatformException(code: code, message: message);

  group('Google : le statut ApiException l’emporte', () {
    for (final (code, status, obstacle) in [
      // DEVELOPER_ERROR : nom de paquet ou SHA-1 inconnus du client Android.
      ('sign_in_failed', 10, SocialSignInObstacle.identiteAppareil),
      // SIGN_IN_FAILED : écran de consentement, utilisateur de test…
      ('sign_in_failed', 12500, SocialSignInObstacle.echec),
      // NETWORK_ERROR : `errorCodeForStatus` rend `network_error`.
      ('network_error', 7, SocialSignInObstacle.reseau),
      // SIGN_IN_REQUIRED.
      ('sign_in_required', 4, SocialSignInObstacle.echec),
      // INTERNAL_ERROR, rangé par le greffon sous `sign_in_failed`.
      ('sign_in_failed', 8, SocialSignInObstacle.echec),
    ]) {
      test('$code / ApiException $status → google-$status', () {
        final failure = googleFailure(sdk(code, '$apiException: $status: '));

        expect(failure.code, 'google-$status');
        expect(failure.obstacle, obstacle);
        expect(failure.provider, SocialProvider.google);
        expect(failure.cause, isA<PlatformException>());
      });
    }

    test('le message complet d’un statut porte aussi son libellé', () {
      final failure = googleFailure(
        sdk('network_error', '$apiException: 7: NETWORK_ERROR'),
      );
      expect(failure.code, 'google-7');
    });

    test('100 n’est pas 10 : la borne de mot entière est respectée', () {
      final failure = googleFailure(
        sdk('sign_in_failed', '$apiException: 100: '),
      );

      expect(failure.code, 'google-100');
      expect(failure.obstacle, SocialSignInObstacle.echec);
    });
  });

  group('Google : sans statut, le code du canal', () {
    for (final (code, message, expected, obstacle) in [
      // `onActivityResult` sans données : « Signin failed », aucun statut.
      (
        'sign_in_failed',
        'Signin failed',
        'google-sign_in_failed',
        SocialSignInObstacle.echec,
      ),
      // `init` ou `getTokens` en échec : `e.getMessage()`.
      (
        'exception',
        'java.lang.IllegalStateException: Activity is null',
        'google-exception',
        SocialSignInObstacle.echec,
      ),
      (
        'user_recoverable_auth',
        'NeedPermission',
        'google-user_recoverable_auth',
        SocialSignInObstacle.echec,
      ),
      (
        'failed_to_recover_auth',
        'Failed attempt to recover authentication',
        'google-failed_to_recover_auth',
        SocialSignInObstacle.echec,
      ),
      // `signOut()` — appelé AVANT chaque demande — peut échouer aussi.
      (
        'status',
        'Failed to signout.',
        'google-status',
        SocialSignInObstacle.echec,
      ),
      (
        'network_error',
        null,
        'google-network_error',
        SocialSignInObstacle.reseau,
      ),
    ]) {
      test('$code → $expected', () {
        final failure = googleFailure(sdk(code, message));

        expect(failure.code, expected);
        expect(failure.obstacle, obstacle);
      });
    }
  });

  group('Google : le canal Pigeon du greffon', () {
    // google_sign_in_android 6.2.1 et google_sign_in_ios 5.9.0 parlent
    // Pigeon (`BasicMessageChannel`), pas `MethodChannel`. Ces exceptions
    // sont copiées de leur `messages.g.dart` et de `Messages.wrapError`.

    test('le natif ne répond rien (channel-error) → google-plugin', () {
      // `_createConnectionError` : greffon absent du build, ou exception
      // Java levée hors du canal d'erreur (le moteur répond alors vide).
      final failure = googleFailure(
        PlatformException(
          code: 'channel-error',
          message:
              'Unable to establish connection on channel: '
              '"dev.flutter.pigeon.google_sign_in_android.GoogleSignInApi'
              '.signIn".',
        ),
      );
      expect(failure.code, 'google-plugin');
      expect(failure.obstacle, SocialSignInObstacle.echec);
      expect(failure.cause, isA<PlatformException>());
    });

    test('exception Java enveloppée : sa classe, jamais son message', () {
      // `wrapError` d'une `Throwable` qui n'est pas une `FlutterError` :
      // code = `exception.toString()`, message = nom court de la classe.
      final failure = googleFailure(
        PlatformException(
          code:
              'java.lang.IllegalStateException: Concurrent operations '
              'detected: signIn, signIn',
          message: 'IllegalStateException',
        ),
      );
      expect(failure.code, 'google-java-illegal-state');
      expect(failure.code, isNot(contains('concurrent')));
      expect(
        googleFailure(
          PlatformException(code: 'java.lang.NullPointerException'),
        ).code,
        'google-java-null-pointer',
      );
      expect(
        googleFailure(PlatformException(code: 'java.lang.Error: x')).code,
        'google-java-error',
      );
    });

    test('valeur nulle rendue par le natif → google-null-error', () {
      final failure = googleFailure(
        PlatformException(
          code: 'null-error',
          message:
              'Host platform returned null value for non-null return value.',
        ),
      );
      expect(failure.code, 'google-null-error');
    });
  });

  group('Google : ce qui n’est pas une PlatformException', () {
    test('greffon à MethodChannel absent → google-plugin', () {
      final failure = googleFailure(
        MissingPluginException(
          'No implementation found for method init on channel '
          'plugins.flutter.io/google_sign_in_android',
        ),
      );
      expect(failure.code, 'google-plugin');
      expect(failure.obstacle, SocialSignInObstacle.echec);
    });

    test('toute autre erreur → google-inattendu, cause gardée', () {
      // Levée par `GoogleSignInAccount.authentication` (google_sign_in
      // 6.3.0) quand le compte n'est plus le compte courant.
      final cause = StateError('User is no longer signed in.');
      final failure = googleFailure(cause);

      expect(failure.code, 'google-inattendu');
      expect(failure.cause, same(cause));
    });
  });

  group('Apple', () {
    for (final (reason, expected) in [
      (AuthorizationErrorCode.failed, 'apple-failed'),
      (AuthorizationErrorCode.invalidResponse, 'apple-invalid-response'),
      (AuthorizationErrorCode.notHandled, 'apple-not-handled'),
      (AuthorizationErrorCode.notInteractive, 'apple-not-interactive'),
      (AuthorizationErrorCode.unknown, 'apple-unknown'),
    ]) {
      test('${reason.name} → $expected', () {
        final failure = appleFailure(
          SignInWithAppleAuthorizationException(code: reason, message: 'x'),
        );
        expect(failure.code, expected);
        expect(failure.provider, SocialProvider.apple);
        expect(failure.obstacle, SocialSignInObstacle.echec);
      });
    }

    test('les exceptions nommées gardent leur code de canal', () {
      expect(
        appleFailure(
          const SignInWithAppleNotSupportedException(message: 'iOS 12'),
        ).code,
        'apple-not-supported',
      );
      expect(
        appleFailure(
          const SignInWithAppleCredentialsException(message: 'x'),
        ).code,
        'apple-credentials-error',
      );
    });

    test('une PlatformException inconnue → apple-<code normalisé>', () {
      expect(
        appleFailure(
          UnknownSignInWithAppleException(
            platformException: PlatformException(code: 'nouveau/Code'),
          ),
        ).code,
        'apple-nouveau-code',
      );
      expect(appleFailure(PlatformException(code: 'x')).code, 'apple-x');
    });

    test('greffon absent, puis tout le reste', () {
      expect(
        appleFailure(MissingPluginException('absent')).code,
        'apple-plugin',
      );
      expect(appleFailure(StateError('?')).code, 'apple-inattendu');
    });
  });

  group('normalisation de la partie variable', () {
    test('minuscules, tirets, soulignés gardés', () {
      expect(codeFragment('sign_in_failed'), 'sign_in_failed');
      expect(codeFragment('invalidResponse'), 'invalid-response');
      expect(
        codeFragment('authorization-error/unknown'),
        'authorization-error-unkn',
      );
    });

    test(
      'ni espace, ni ponctuation, ni accent, ni @ : rien à mal recopier',
      () {
        final fragment = codeFragment(
          '  Échec   réseau !! « compte@exemple.fr » ',
        );
        expect(fragment, matches(RegExp(r'^[a-z0-9_-]+$')));
        expect(fragment, isNot(contains('@')));
        expect(fragment.length, lessThanOrEqualTo(24));
      },
    );

    test('longueur bornée, jamais de tiret final', () {
      // La coupe à 24 tombe juste après le tiret : il ne doit pas rester.
      final fragment = codeFragment('${'a' * 23}-${'b' * 40}');
      expect(fragment, 'a' * 23);
      expect(codeFragment('x' * 60).length, 24);
    });

    test('rien d’exploitable → inconnu', () {
      expect(codeFragment(''), 'inconnu');
      expect(codeFragment('///'), 'inconnu');
    });
  });
}
