import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/features/authentication/data/datasources/social_sign_in.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_provider.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// CE QUE CE FICHIER PROTÈGE : la passerelle vers le SDK Google n'avait aucun
/// test, et deux de ses défauts ne se voyaient qu'à l'usage, sur un vrai
/// téléphone, après plusieurs minutes.
///
/// 1. `signOut()` AVANT `signIn()`. Android ne sait pas régénérer un jeton
///    d'identité — le greffon le dit dans son propre code source
///    (google_sign_in 6.3.0, lib/google_sign_in.dart:100-102 : « there isn't
///    an API for refreshing the idToken, so re-use the one we obtained on
///    login ») — et `signIn()` rend le compte en cache sans rouvrir la
///    feuille. Sans cet oubli préalable, le deuxième appui renvoie le jeton
///    de la PREMIÈRE connexion : le serveur le refuse passé sa fenêtre
///    d'âge, et la connexion, qui marchait, cesse de marcher.
/// 2. Le statut 10 (`DEVELOPER_ERROR`) n'est pas « pas encore configuré ».
///    Il veut dire que Google Cloud ne reconnaît pas cet APK. Les confondre
///    envoyait chercher une variable d'environnement absente alors que le
///    build était correct.
///
/// Un compte Google ne peut pas être fabriqué dans un test — `GoogleSignIn
/// Account` n'a qu'un constructeur privé. Ces tests couvrent donc l'ordre des
/// appels et les chemins d'échec, qui sont précisément ceux qui régressaient.
void main() {
  const environnement = AppEnvironment(
    flavor: AppFlavor.development,
    apiBaseUrl: 'http://localhost:3000',
    googleServerClientId: 'web-client.apps.googleusercontent.com',
  );

  test(
    'oublie le compte AVANT de demander, pour obtenir un jeton frais',
    () async {
      final google = _GoogleEnregistreur();
      final passerelle = PlatformSocialSignIn(
        environment: environnement,
        google: google,
      );

      final credential = await passerelle.obtain(SocialProvider.google);

      expect(
        credential,
        isNull,
        reason: 'signIn() a rendu null : la personne a renoncé',
      );
      expect(
        google.appels,
        ['signOut', 'signIn'],
        reason:
            'signOut doit précéder signIn, sinon le jeton rendu est celui '
            'de la première connexion et le serveur le refusera',
      );
    },
  );

  test('le statut 10 devient identiteAppareil, pas configuration', () async {
    final google = _GoogleEnregistreur(
      erreur: PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 10: ',
      ),
    );
    final passerelle = PlatformSocialSignIn(
      environment: environnement,
      google: google,
    );

    await expectLater(
      passerelle.obtain(SocialProvider.google),
      throwsA(
        isA<SocialSignInUnavailable>()
            .having(
              (e) => e.obstacle,
              'obstacle',
              SocialSignInObstacle.identiteAppareil,
            )
            .having((e) => e.cause, 'cause', isA<PlatformException>()),
      ),
    );
  });

  test('un autre échec du SDK reste une configuration incomplète', () async {
    final google = _GoogleEnregistreur(
      erreur: PlatformException(
        code: 'sign_in_failed',
        message:
            'com.google.android.gms.common.api.ApiException: 7: NETWORK_ERROR',
      ),
    );
    final passerelle = PlatformSocialSignIn(
      environment: environnement,
      google: google,
    );

    await expectLater(
      passerelle.obtain(SocialProvider.google),
      throwsA(
        isA<SocialSignInUnavailable>().having(
          (e) => e.obstacle,
          'obstacle',
          SocialSignInObstacle.configuration,
        ),
      ),
    );
  });

  test('100 n’est pas 10 : la borne de mot entière est respectée', () async {
    // `:\s*10\b` et non `contains(': 10')` : un statut 100 inconnu ne doit
    // pas se faire passer pour DEVELOPER_ERROR.
    final google = _GoogleEnregistreur(
      erreur: PlatformException(
        code: 'sign_in_failed',
        message: 'com.google.android.gms.common.api.ApiException: 100: ',
      ),
    );
    final passerelle = PlatformSocialSignIn(
      environment: environnement,
      google: google,
    );

    await expectLater(
      passerelle.obtain(SocialProvider.google),
      throwsA(
        isA<SocialSignInUnavailable>().having(
          (e) => e.obstacle,
          'obstacle',
          SocialSignInObstacle.configuration,
        ),
      ),
    );
  });

  test('sans client OAuth, la passerelle ne touche même pas le SDK', () async {
    final google = _GoogleEnregistreur();
    final passerelle = PlatformSocialSignIn(
      environment: const AppEnvironment(
        flavor: AppFlavor.development,
        apiBaseUrl: 'http://localhost:3000',
      ),
      google: google,
    );

    await expectLater(
      passerelle.obtain(SocialProvider.google),
      throwsA(
        isA<SocialSignInUnavailable>().having(
          (e) => e.obstacle,
          'obstacle',
          SocialSignInObstacle.configuration,
        ),
      ),
    );
    expect(google.appels, isEmpty, reason: 'rien à demander sans client OAuth');
  });
}

/// Faux SDK Google : il n'ouvre rien, il NOTE l'ordre des appels.
class _GoogleEnregistreur extends GoogleSignIn {
  _GoogleEnregistreur({this.erreur}) : super(scopes: const ['email']);

  /// Levée par `signIn()` quand elle est fournie ; sinon `signIn()` rend
  /// `null`, ce que le SDK fait quand la personne referme la feuille.
  final PlatformException? erreur;

  final List<String> appels = [];

  @override
  Future<GoogleSignInAccount?> signIn() async {
    appels.add('signIn');
    final aLever = erreur;
    if (aLever != null) throw aLever;
    return null;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    appels.add('signOut');
    return null;
  }
}
