import 'dart:convert';

import 'package:carlys_mobile/core/auth/token_storage.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/authentication/data/datasources/auth_api.dart';
import 'package:carlys_mobile/features/authentication/data/datasources/social_sign_in.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_provider.dart';
import 'package:carlys_mobile/features/authentication/presentation/utils/social_auth_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_secure_storage.dart';

/// Ce que ces tests protègent : l'OUVERTURE d'une session par le dépôt —
/// appel, lecture de la réponse, enregistrement des jetons — et le TYPE de
/// chaque échec.
///
/// Avant : une réponse illisible sortait en `TypeError` brute, un trousseau
/// qui refuse en `PlatformException` brute ; les deux finissaient au filet du
/// contrôleur, sous la même phrase, sans que rien ne dise lequel avait joué.
/// Et le jeton que le trousseau n'avait pas pris restait en mémoire : une
/// session à moitié ouverte.
void main() {
  late List<String> requests;
  late Dio dio;
  late FakeSecureStorage secure;
  late TokenStorage storage;

  /// Le serveur : la réponse de `/auth/social` (et `/auth/login`), et 204 à
  /// la révocation.
  void serve(int status, Object body) {
    dio.httpClientAdapter = _Adapter((options) async {
      requests.add('${options.method} ${options.path}');
      if (options.path == '/auth/logout') {
        return ResponseBody.fromString('', 204);
      }
      return ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });
  }

  /// Le serveur répond [status] avec un corps BRUT : ce que renvoie un
  /// portail captif, un proxy, ou une adresse d'API qui pointe ailleurs.
  void serveRaw(
    int status,
    String body, {
    required String contentType,
    String? requestId,
  }) {
    dio.httpClientAdapter = _Adapter((options) async {
      requests.add('${options.method} ${options.path}');
      return ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [contentType],
          if (requestId != null) 'x-request-id': [requestId],
        },
      );
    });
  }

  AuthRepositoryImpl repository() => AuthRepositoryImpl(
    api: AuthApi(dio),
    storage: storage,
    socialSignIn: _Credential(),
  );

  Map<String, Object?> session({Map<String, Object?>? user}) => {
    'data': {
      'user':
          user ??
          {
            'id': 'u-1',
            'email': 'camille@example.com',
            'displayName': 'Camille',
            'emailVerified': true,
            'locale': 'fr',
            'timezone': 'Europe/Paris',
          },
      'tokens': {'accessToken': 'acces', 'refreshToken': 'renouvellement'},
    },
    'meta': <String, Object?>{},
    'requestId': 'r-1',
  };

  setUp(() {
    requests = [];
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
    secure = FakeSecureStorage();
    storage = TokenStorage(secure);
  });

  test('une réponse complète : session ouverte et jetons gardés', () async {
    serve(200, session());

    final user = await repository().signInWithProvider(SocialProvider.google);

    expect(user?.id, 'u-1');
    expect(await storage.readAccessToken(), 'acces');
    expect(await storage.hasSession, isTrue);
  });

  test('un champ manquant → MalformedResponseException, rien gardé', () async {
    // `displayName` absent : `json['displayName'] as String` lève une
    // `TypeError`, qui traversait le dépôt telle quelle.
    serve(
      200,
      session(
        user: {
          'id': 'u-1',
          'email': 'camille@example.com',
          'emailVerified': true,
          'locale': 'fr',
          'timezone': 'Europe/Paris',
        },
      ),
    );

    await expectLater(
      repository().signInWithProvider(SocialProvider.google),
      throwsA(
        isA<MalformedResponseException>().having(
          (e) => e.cause,
          'cause',
          isA<TypeError>(),
        ),
      ),
    );
    expect(await storage.hasSession, isFalse);
  });

  test('pas d’enveloppe → MalformedResponseException', () async {
    serve(200, {'inattendu': true});

    await expectLater(
      repository().login(email: 'camille@example.com', password: 'x'),
      throwsA(
        isA<MalformedResponseException>().having(
          (e) => e.cause,
          'cause',
          isA<FormatException>(),
        ),
      ),
    );
  });

  // Un hôte qui a RÉPONDU 200 avec un corps illisible. Avant : l'échec
  // naissait DANS Dio (`response.data as Map`, décodeur JSON), enveloppé en
  // `unknown` comme une coupure, et la personne lisait « Le serveur Carlys
  // est injoignable » (`reseau-inconnu`) : exactement la mauvaise piste.
  group('200 dont le corps ne se lit pas → appli-reponse, jamais réseau', () {
    for (final (name, body, contentType) in [
      ('page HTML', '<html>portail</html>', 'text/html; charset=utf-8'),
      ('liste JSON', '[1,2]', Headers.jsonContentType),
    ]) {
      test('$name, avec l’en-tête de l’API : la réf. suit', () async {
        serveRaw(
          200,
          body,
          contentType: contentType,
          requestId: '1a2b3c4d-0000-4000-8000-000000000000',
        );

        final error = await repository()
            .signInWithProvider(SocialProvider.google)
            .then<Object?>((_) => null, onError: (Object e) => e);

        expect(error, isA<MalformedResponseException>());
        final failure = describeSocialFailure(SocialProvider.google, error!);
        expect(failure.code, 'appli-reponse');
        expect(failure.reference, '1a2b3c4d');
        expect(await storage.hasSession, isFalse);
      });
    }

    test('JSON tronqué : illisible aussi, décodé par Dio lui-même', () async {
      serveRaw(
        200,
        '{"data": {"user":',
        contentType: Headers.jsonContentType,
        requestId: '1a2b3c4d-0000',
      );

      final error = await repository()
          .login(email: 'camille@example.com', password: 'x')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<MalformedResponseException>());
      expect(
        describeSocialFailure(SocialProvider.google, error!).code,
        'appli-reponse',
      );
    });

    test('sans l’en-tête de l’API : pas de réf. inventée', () async {
      // Autre chose que l'API a répondu (portail, adresse d'API fausse) :
      // l'absence de référence le dit.
      serveRaw(200, '<html>portail</html>', contentType: 'text/html');

      final error = await repository()
          .signInWithProvider(SocialProvider.google)
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(error, isA<MalformedResponseException>());
      expect((error! as AppException).requestId, isNull);
    });
  });

  test('trousseau qui refuse → StorageException, session rendue', () async {
    serve(200, session());
    secure.failWrites = PlatformException(code: 'Keystore', message: 'KO');

    await expectLater(
      repository().signInWithProvider(SocialProvider.google),
      throwsA(
        isA<StorageException>().having(
          (e) => e.cause,
          'cause',
          isA<PlatformException>(),
        ),
      ),
    );
    // Le serveur a ouvert une session que l'appareil ne sait pas garder :
    // elle est révoquée, et le jeton que le cache mémoire avait pris est
    // oublié — plus de session à moitié ouverte.
    expect(requests, contains('POST /auth/logout'));
    expect(await storage.readAccessToken(), isNull);
  });

  test(
    'refus du serveur : statut et requestId portés jusqu’au domaine',
    () async {
      serve(401, {
        'error': {
          'code': 'UNAUTHORIZED',
          'message':
              'Google n’a pas pu confirmer ton identité. Réessaie, ou '
              'utilise ton adresse e-mail.',
          'details': <Object?>[],
          'requestId': '1a2b3c4d-aaaa',
        },
      });

      await expectLater(
        repository().signInWithProvider(SocialProvider.google),
        throwsA(
          isA<UnauthorizedException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.requestId, 'requestId', '1a2b3c4d-aaaa')
              .having(
                (e) => e.message,
                'message',
                startsWith('Google n’a pas pu confirmer ton identité.'),
              ),
        ),
      );
    },
  );
}

/// Adaptateur HTTP factice : chaque requête passe par [_handler].
class _Adapter implements HttpClientAdapter {
  _Adapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => _handler(options);

  @override
  void close({bool force = false}) {}
}

/// Le fournisseur rend toujours un jeton : ces tests portent sur ce que le
/// dépôt en fait ENSUITE.
class _Credential implements SocialSignIn {
  @override
  Future<SocialCredential?> obtain(SocialProvider provider) async =>
      const SocialCredential(idToken: 'jeton-du-fournisseur');

  @override
  Future<void> forget() async {}
}
