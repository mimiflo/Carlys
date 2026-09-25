import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/features/authentication/data/datasources/social_sign_in.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_provider.dart';
import 'package:flutter/services.dart';
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
            .having((e) => e.code, 'code', 'google-10')
            .having((e) => e.cause, 'cause', isA<PlatformException>()),
      ),
    );
  });

  test('le statut 7 est le RÉSEAU de Google, pas une configuration', () async {
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
        isA<SocialSignInUnavailable>()
            .having((e) => e.obstacle, 'obstacle', SocialSignInObstacle.reseau)
            .having((e) => e.code, 'code', 'google-7'),
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
        isA<SocialSignInUnavailable>()
            .having((e) => e.obstacle, 'obstacle', SocialSignInObstacle.echec)
            .having((e) => e.code, 'code', 'google-100'),
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
        isA<SocialSignInUnavailable>()
            .having(
              (e) => e.obstacle,
              'obstacle',
              SocialSignInObstacle.configuration,
            )
            .having((e) => e.code, 'code', 'google-config-web'),
      ),
    );
    expect(google.appels, isEmpty, reason: 'rien à demander sans client OAuth');
  });

  test(
    'une erreur du SDK qui n’est PAS une PlatformException est enveloppée',
    () async {
      // Le défaut réparé : une `StateError` (celle de
      // `GoogleSignInAccount.authentication`) ou une `MissingPluginException`
      // traversait la passerelle et finissait au filet du contrôleur — un
      // échec anonyme, sans fournisseur ni code.
      final passerelle = PlatformSocialSignIn(
        environment: environnement,
        google: _GoogleEnregistreur(
          erreur: StateError('User is no longer signed in.'),
        ),
      );

      await expectLater(
        passerelle.obtain(SocialProvider.google),
        throwsA(
          isA<SocialSignInUnavailable>()
              .having((e) => e.code, 'code', 'google-inattendu')
              .having((e) => e.cause, 'cause', isStateError),
        ),
      );
    },
  );

  test(
    'Apple hors iPhone et iPad : apple-plateforme, sans ouvrir le SDK',
    () async {
      // La machine de test n'est ni iOS ni macOS : c'est Android, pour la
      // passerelle.
      final passerelle = PlatformSocialSignIn(
        environment: environnement,
        google: _GoogleEnregistreur(),
      );

      await expectLater(
        passerelle.obtain(SocialProvider.apple),
        throwsA(
          isA<SocialSignInUnavailable>()
              .having(
                (e) => e.obstacle,
                'obstacle',
                SocialSignInObstacle.plateforme,
              )
              .having((e) => e.code, 'code', 'apple-plateforme'),
        ),
      );
    },
  );

  /// Le VRAI `GoogleSignIn`, branché sur un canal de plateforme simulé.
  ///
  /// Le compte Google ne se fabrique pas, mais le greffon le construit
  /// lui-même à partir de ce que le canal lui rend : c'est ainsi que se
  /// teste ce qui dépend du compte (jeton absent, échec de `getTokens`) et
  /// ce qui dépend du canal (greffon absent), avec le code du greffon entre
  /// les deux plutôt qu'une doublure.
  group('à travers le vrai greffon', () {
    const canal = MethodChannel('plugins.flutter.io/google_sign_in');
    TestDefaultBinaryMessenger messager() =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    PlatformSocialSignIn passerelleReelle() => PlatformSocialSignIn(
      environment: environnement,
      google: GoogleSignIn(
        scopes: const ['email'],
        serverClientId: environnement.googleServerClientId,
      ),
    );

    /// Répond comme le greffon Android : `init` et `signOut` sans rien,
    /// `signIn` avec un compte, `getTokens` avec ce qu'on lui donne.
    void simule({Object? Function()? signIn, Object? Function()? getTokens}) {
      messager().setMockMethodCallHandler(canal, (appel) async {
        return switch (appel.method) {
          'signIn' => (signIn ?? () => _compte(idToken: 'jeton-id'))(),
          'getTokens' =>
            (getTokens ?? () => <String, Object?>{'accessToken': 'a'})(),
          _ => null,
        };
      });
    }

    setUp(() => TestWidgetsFlutterBinding.ensureInitialized());
    tearDown(() => messager().setMockMethodCallHandler(canal, null));

    test('un jeton rendu : la passerelle le transmet', () async {
      simule();

      final credential = await passerelleReelle().obtain(SocialProvider.google);

      expect(credential?.idToken, 'jeton-id');
      expect(credential?.displayName, 'Camille');
    });

    test('compte ouvert SANS jeton d’identité → google-sans-jeton', () async {
      // Ce que fait Google quand `serverClientId` n'est pas un client de
      // type « Web » : un compte, et pas de jeton pour notre serveur.
      simule(signIn: () => _compte(idToken: null));

      await expectLater(
        passerelleReelle().obtain(SocialProvider.google),
        throwsA(
          isA<SocialSignInUnavailable>()
              .having((e) => e.code, 'code', 'google-sans-jeton')
              .having(
                (e) => e.obstacle,
                'obstacle',
                SocialSignInObstacle.configuration,
              ),
        ),
      );
    });

    test('l’échec de getTokens garde son code', () async {
      simule(
        getTokens: () => throw PlatformException(
          code: 'failed_to_recover_auth',
          message: 'Failed attempt to recover authentication',
        ),
      );

      await expectLater(
        passerelleReelle().obtain(SocialProvider.google),
        throwsA(
          isA<SocialSignInUnavailable>().having(
            (e) => e.code,
            'code',
            'google-failed_to_recover_auth',
          ),
        ),
      );
    });

    test('12500 remonte du greffon jusqu’au code', () async {
      simule(
        signIn: () => throw PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 12500: ',
        ),
      );

      await expectLater(
        passerelleReelle().obtain(SocialProvider.google),
        throwsA(
          isA<SocialSignInUnavailable>().having(
            (e) => e.code,
            'code',
            'google-12500',
          ),
        ),
      );
    });

    test('feuille refermée (12501) : null, rien à dire', () async {
      simule(
        signIn: () => throw PlatformException(
          code: 'sign_in_canceled',
          message: 'com.google.android.gms.common.api.ApiException: 12501: ',
        ),
      );

      expect(await passerelleReelle().obtain(SocialProvider.google), isNull);
    });

    test('le natif ne répond rien (Pigeon) → google-plugin', () async {
      // LA forme réelle sur Android et iOS : google_sign_in_android 6.2.1 et
      // google_sign_in_ios 5.9.0 parlent Pigeon, et un natif qui ne répond
      // rien y lève `channel-error` (`_createConnectionError`, copiée de
      // leur `messages.g.dart`), jamais `MissingPluginException`. Le natif
      // ne répond rien quand le greffon manque au build, mais aussi quand
      // `GoogleSignInPlugin` lève hors de son canal d'erreur (« signIn
      // needs a foreground activity ») : `DartMessenger` rattrape et répond
      // VIDE. Le greffon Pigeon lui-même ne peut pas être branché ici sans
      // ajouter `google_sign_in_android` aux dépendances : c'est donc son
      // exception, telle qu'il la lève, qui passe par le vrai `GoogleSignIn`.
      messager().setMockMethodCallHandler(canal, (appel) async {
        throw PlatformException(
          code: 'channel-error',
          message:
              'Unable to establish connection on channel: '
              '"dev.flutter.pigeon.google_sign_in_android.GoogleSignInApi'
              '.${appel.method}".',
        );
      });

      await expectLater(
        passerelleReelle().obtain(SocialProvider.google),
        throwsA(
          isA<SocialSignInUnavailable>()
              .having((e) => e.code, 'code', 'google-plugin')
              .having((e) => e.cause, 'cause', isA<PlatformException>()),
        ),
      );
    });

    test('greffon à MethodChannel absent → google-plugin', () async {
      // Aucun gestionnaire sur le canal historique : l'implémentation par
      // `MethodChannel` lève `MissingPluginException`. Ce n'est PAS ce que
      // voit un téléphone (voir le test précédent) : c'est ce qui reste
      // quand aucune implémentation de plateforme n'est enregistrée
      // (bureau, tests), et la forme qu'a aussi un greffon Apple absent.
      messager().setMockMethodCallHandler(canal, null);

      await expectLater(
        passerelleReelle().obtain(SocialProvider.google),
        throwsA(
          isA<SocialSignInUnavailable>().having(
            (e) => e.code,
            'code',
            'google-plugin',
          ),
        ),
      );
    });
  });
}

/// Un compte tel que le greffon Android le décrit à Dart.
Map<String, Object?> _compte({required String? idToken}) => {
  'email': 'camille@example.com',
  'id': '1234',
  'displayName': 'Camille',
  'photoUrl': null,
  'idToken': idToken,
  'serverAuthCode': null,
};

/// Faux SDK Google : il n'ouvre rien, il NOTE l'ordre des appels.
class _GoogleEnregistreur extends GoogleSignIn {
  _GoogleEnregistreur({this.erreur}) : super(scopes: const ['email']);

  /// Levée par `signIn()` quand elle est fournie ; sinon `signIn()` rend
  /// `null`, ce que le SDK fait quand la personne referme la feuille.
  final Object? erreur;

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
