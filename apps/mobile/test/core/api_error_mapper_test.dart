import 'dart:io' show HandshakeException, SocketException;

import 'package:carlys_mobile/core/api/api_error_mapper.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que `mapDioException` retient d'un échec pour le DIAGNOSTIC : le
/// statut HTTP et l'identifiant de requête sur toute la hiérarchie, et la
/// forme d'un échec de transport. La présentation ne lit jamais Dio : si ce
/// n'est pas porté ici, c'est perdu.
void main() {
  final options = RequestOptions(path: '/auth/social');

  DioException reponse(
    int status, {
    Object? body,
    Map<String, List<String>> headers = const {},
  }) => DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers),
    ),
  );

  Map<String, Object?> enveloppe(String message, {String? requestId}) => {
    'error': {
      'code': 'UNAUTHORIZED',
      'message': message,
      'details': <Object?>[],
      if (requestId != null) 'requestId': requestId,
    },
  };

  group('réponse d’erreur : statut et requestId portés partout', () {
    for (final (status, type) in [
      (401, UnauthorizedException),
      (403, ForbiddenException),
      (400, ValidationException),
      (409, ValidationException),
      (422, ValidationException),
      (429, ServerException),
      (500, ServerException),
      (503, ServerException),
    ]) {
      test('$status → $type', () {
        final error = mapDioException(
          reponse(
            status,
            body: enveloppe('Refusé.', requestId: '1a2b3c4d-9999-4000-8000-0'),
          ),
        );

        expect(error.runtimeType, type);
        expect(error.statusCode, status);
        expect(error.requestId, '1a2b3c4d-9999-4000-8000-0');
        expect(error.transport, isNull);
        expect(error.fromApi, isTrue, reason: 'l’enveloppe de l’API');
      });

      test(
        '$status sans enveloppe (page d’un intermédiaire) : pas de l’API',
        () {
          final error = mapDioException(
            reponse(status, body: '<html>nginx</html>'),
          );
          expect(error.runtimeType, type);
          expect(error.statusCode, status);
          expect(error.fromApi, isFalse);
        },
      );
    }

    test('le message de l’enveloppe reste celui de l’erreur', () {
      final error = mapDioException(
        reponse(401, body: enveloppe('Jeton Google invalide.')),
      );
      expect(error.message, 'Jeton Google invalide.');
    });

    test('sans enveloppe, l’en-tête x-request-id prend le relais', () {
      final error = mapDioException(
        reponse(
          502,
          body: '<html>Bad Gateway</html>',
          headers: {
            requestIdHeader: ['abcdef12-0000'],
          },
        ),
      );
      expect(error.statusCode, 502);
      expect(error.requestId, 'abcdef12-0000');
    });

    test('ni enveloppe ni en-tête : pas de référence inventée', () {
      // nginx qui répond à la place de l'API : aucun identifiant.
      final error = mapDioException(reponse(504, body: '<html></html>'));
      expect(error.requestId, isNull);
    });

    test('en-tête x-request-id répété, pas d’enveloppe : jamais d’exception '
        'brute', () {
      // `Headers.value` LÈVE quand l'en-tête a plusieurs valeurs (l'API en
      // pose un, un proxy de corrélation peut en ajouter un second). Le
      // convertisseur jetait alors une `Exception` brute au lieu de rendre
      // l'`AppException` : `http-502` devenait `appli-inattendu`.
      final error = mapDioException(
        reponse(
          502,
          body: '<html>502</html>',
          headers: {
            requestIdHeader: ['aaaaaaaa-1111', 'bbbbbbbb-2222'],
          },
        ),
      );
      expect(error, isA<ServerException>());
      expect(error.statusCode, 502);
      // La première valeur : celle de l'amont, que le proxy relaie avant
      // d'ajouter la sienne.
      expect(error.requestId, 'aaaaaaaa-1111');
    });

    test('un identifiant qui n’en a pas la forme est ignoré', () {
      final error = mapDioException(
        reponse(
          500,
          body: enveloppe('x', requestId: 'pas un identifiant <script>'),
          headers: {
            requestIdHeader: ['a' * 80],
          },
        ),
      );
      expect(error.requestId, isNull);
    });
  });

  group('aucune réponse : la forme du transport', () {
    for (final (type, transport, kind) in [
      (
        DioExceptionType.connectionTimeout,
        TransportFailure.timeout,
        NetworkException,
      ),
      (
        DioExceptionType.receiveTimeout,
        TransportFailure.timeout,
        NetworkException,
      ),
      (
        DioExceptionType.sendTimeout,
        TransportFailure.timeout,
        NetworkException,
      ),
      (
        DioExceptionType.connectionError,
        TransportFailure.connection,
        NetworkException,
      ),
      (
        DioExceptionType.badCertificate,
        TransportFailure.certificate,
        UnknownException,
      ),
      (DioExceptionType.cancel, TransportFailure.other, UnknownException),
    ]) {
      test('${type.name} → ${transport.name}', () {
        final error = mapDioException(
          DioException(requestOptions: options, type: type),
        );
        expect(error.transport, transport);
        // Le TYPE ne change pas : « hors ligne » reste ce qu'il était pour
        // tous les écrans qui s'en servent.
        expect(error.runtimeType, kind);
        expect(error.statusCode, isNull);
      });
    }

    test('certificat refusé par le système : c’est un certificat', () {
      // Forme réelle sur un téléphone : l'adaptateur d'E/S laisse filer la
      // `HandshakeException`, que Dio enveloppe en `unknown`.
      final error = mapDioException(
        DioException(
          requestOptions: options,
          error: const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        ),
      );
      expect(error.transport, TransportFailure.certificate);
    });

    // Une réponse 2xx que Dio n'a pas pu décoder : l'hôte a RÉPONDU. Ni
    // délai, ni coupure : le dire « injoignable » enverrait vérifier le
    // réseau alors que c'est ce qui a répondu qu'il faut regarder.
    test('JSON tronqué (FormatException dans Dio) → réponse illisible', () {
      final error = mapDioException(
        DioException(
          requestOptions: options,
          error: const FormatException('Unexpected end of input'),
        ),
      );
      expect(error, isA<MalformedResponseException>());
      expect(error.transport, isNull);
    });

    test('corps d’un autre type (TypeError dans Dio) → réponse illisible', () {
      Object? typeError;
      try {
        // Exactement ce que fait `assureResponse` : `response.data as T?`.
        final Object body = '<html>portail</html>';
        body as Map<String, dynamic>;
      } on TypeError catch (error) {
        typeError = error;
      }
      final error = mapDioException(
        DioException(requestOptions: options, error: typeError),
      );
      expect(error, isA<MalformedResponseException>());
      expect(error.transport, isNull);
    });

    test('un autre `unknown` reste inconnu', () {
      final error = mapDioException(
        DioException(
          requestOptions: options,
          error: const SocketException('reset'),
        ),
      );
      expect(error.transport, TransportFailure.other);
    });
  });
}
