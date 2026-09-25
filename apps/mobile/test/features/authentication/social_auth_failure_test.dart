import 'dart:io';

import 'package:carlys_mobile/core/api/api_error_mapper.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/authentication/data/datasources/social_sign_in.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_provider.dart';
import 'package:carlys_mobile/features/authentication/presentation/utils/social_auth_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la liste FERMÉE des codes d'échec de la
/// connexion sociale, et la phrase qui accompagne chacun.
///
/// Le défaut d'origine : une seule phrase — « La connexion avec Google n’a
/// pas abouti » — sortait pour une douzaine de causes (500, 502, 429,
/// réseau, certificat, réponse illisible, trousseau, purge locale, erreur
/// imprévue du SDK), et rien, ni à l'écran ni dans un journal lisible en
/// production, ne permettait de savoir laquelle.
void main() {
  const google = SocialProvider.google;

  SocialAuthFailure of(Object error) => describeSocialFailure(google, error);

  /// Une réponse d'erreur telle que l'API l'écrit, passée par le VRAI
  /// convertisseur : ce test éprouve la chaîne entière, pas une doublure.
  AppException http(int status, {String? message, String? requestId}) {
    final options = RequestOptions(path: '/auth/social');
    return mapDioException(
      DioException.badResponse(
        statusCode: status,
        requestOptions: options,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: status,
          data: message == null
              ? '<html>nginx</html>'
              : {
                  'error': {
                    'code': 'X',
                    'message': message,
                    'details': <Object?>[],
                    if (requestId != null) 'requestId': requestId,
                  },
                },
        ),
      ),
    );
  }

  AppException transport(DioExceptionType type, {Object? error}) =>
      mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/social'),
          type: type,
          error: error,
        ),
      );

  group('SDK, avant le serveur', () {
    test('client Web absent du build : arrive bientôt, sans ton de panne', () {
      final failure = of(
        const SocialSignInUnavailable(
          google,
          SocialSignInObstacle.configuration,
          code: 'google-config-web',
        ),
      );
      expect(failure.code, 'google-config-web');
      expect(
        failure.message,
        contains('La connexion avec Google arrive bientôt'),
      );
      expect(failure.unavailable, isTrue);
      expect(failure.reference, isNull);
    });

    test('Apple hors iPhone : la raison, et le code', () {
      final failure = describeSocialFailure(
        SocialProvider.apple,
        const SocialSignInUnavailable(
          SocialProvider.apple,
          SocialSignInObstacle.plateforme,
          code: 'apple-plateforme',
        ),
      );
      expect(failure.code, 'apple-plateforme');
      expect(failure.message, contains('n’existe que sur iPhone et iPad'));
      expect(failure.unavailable, isTrue);
      expect(failure.severe, isFalse);
    });

    test('google-10 : Google ne reconnaît pas cette version', () {
      final failure = of(
        const SocialSignInUnavailable(
          google,
          SocialSignInObstacle.identiteAppareil,
          code: 'google-10',
        ),
      );
      expect(failure.code, 'google-10');
      expect(
        failure.message,
        'Google n’a pas reconnu cette version de l’application. Utilise ton '
        'adresse e-mail en attendant.',
      );
      expect(failure.unavailable, isFalse);
    });

    test('google-7 : Google injoignable', () {
      final failure = of(
        const SocialSignInUnavailable(
          google,
          SocialSignInObstacle.reseau,
          code: 'google-7',
        ),
      );
      expect(
        failure.message,
        'Google n’est pas joignable. Vérifie ta connexion, puis réessaie.',
      );
      expect(failure.severe, isFalse);
    });

    test('google-12500 : Google n’a pas pu terminer', () {
      final failure = of(
        const SocialSignInUnavailable(
          google,
          SocialSignInObstacle.echec,
          code: 'google-12500',
        ),
      );
      expect(failure.code, 'google-12500');
      expect(
        failure.message,
        'Google n’a pas pu terminer la connexion. Réessaie, ou utilise ton '
        'adresse e-mail.',
      );
      expect(failure.severe, isTrue);
    });
  });

  group('réseau vers Carlys', () {
    for (final (type, error, code) in [
      (DioExceptionType.connectionTimeout, null, 'reseau-delai'),
      (DioExceptionType.receiveTimeout, null, 'reseau-delai'),
      (DioExceptionType.connectionError, null, 'reseau-connexion'),
      (DioExceptionType.badCertificate, null, 'reseau-certificat'),
      (
        DioExceptionType.unknown,
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        'reseau-certificat',
      ),
      (DioExceptionType.unknown, null, 'reseau-inconnu'),
      (DioExceptionType.cancel, null, 'reseau-inconnu'),
    ]) {
      test('${type.name}${error == null ? '' : ' (TLS)'} → $code', () {
        final failure = of(transport(type, error: error));
        expect(failure.code, code);
        expect(
          failure.reference,
          isNull,
          reason: 'aucune réponse, aucune réf.',
        );
      });
    }

    test('injoignable : la phrase dit quoi faire', () {
      expect(
        of(transport(DioExceptionType.connectionError)).message,
        'Le serveur Carlys est injoignable. Vérifie ta connexion, puis '
        'réessaie.',
      );
    });

    test('certificat : jamais une invitation à contourner', () {
      final message = of(transport(DioExceptionType.badCertificate)).message;
      expect(message, contains('date de ton téléphone'));
      expect(message, isNot(matches(RegExp('accepte|ignore|quand même'))));
    });
  });

  group('réponse HTTP d’erreur', () {
    test('429 : attendre une minute, avec la référence', () {
      final failure = of(
        http(429, message: 'Too Many', requestId: '9f8e7d6c-1'),
      );
      expect(failure.code, 'http-429');
      expect(
        failure.message,
        'Trop de tentatives de connexion. Attends une minute, puis réessaie.',
      );
      expect(failure.reference, '9f8e7d6c');
      expect(failure.requestId, '9f8e7d6c-1');
    });

    test('503 : fournisseur pas encore activé sur le serveur', () {
      final failure = of(
        http(503, message: 'Une erreur interne', requestId: 'r'),
      );
      expect(failure.code, 'http-503');
      expect(failure.message, contains('arrive bientôt'));
      expect(failure.unavailable, isTrue);
    });

    test('503 de nginx (API arrêtée) : une panne, pas « arrive bientôt »', () {
      // Aucune enveloppe : c'est un intermédiaire qui a répondu, pas l'API
      // qui dit « fournisseur non activé ».
      final failure = of(http(503));
      expect(failure.code, 'http-503');
      expect(failure.unavailable, isFalse);
      expect(
        failure.message,
        'Le serveur Carlys n’a pas pu ouvrir ta session. Réessaie dans un '
        'instant.',
      );
    });

    for (final status in [401, 403]) {
      test('$status sans enveloppe : jamais le texte technique de la page '
          'd’erreur', () {
        final failure = of(http(status));
        expect(failure.code, 'http-$status');
        expect(failure.message, isNot(contains('a répondu avec une erreur')));
        expect(failure.message, contains('n’a pas pu ouvrir ta session'));
      });
    }

    for (final status in [400, 401, 403, 409, 422]) {
      test('$status : le message du serveur, écrit pour la personne', () {
        final failure = of(
          http(
            status,
            message: 'Le fournisseur n’a pas transmis d’adresse vérifiée.',
            requestId: '1a2b3c4d-ffff',
          ),
        );
        expect(failure.code, 'http-$status');
        expect(
          failure.message,
          'Le fournisseur n’a pas transmis d’adresse vérifiée.',
        );
        expect(
          failure.codeLine,
          'Code\u00A0: http-$status · réf.\u00A01a2b3c4d',
        );
      });
    }

    test('apostrophes droites du serveur : courbes à l’écran', () {
      // Le texte RÉEL que l'API écrivait pour une adresse non vérifiée, avec
      // ses apostrophes droites ; un serveur plus ancien que l'application
      // l'écrit encore.
      final failure = of(
        http(
          401,
          message:
              "Le fournisseur n'a pas transmis d'adresse e-mail vérifiée. "
              'Connecte-toi avec ton adresse e-mail.',
          requestId: '1a2b3c4d-ffff',
        ),
      );
      expect(
        failure.message,
        'Le fournisseur n’a pas transmis d’adresse e-mail vérifiée. '
        'Connecte-toi avec ton adresse e-mail.',
      );
    });

    for (final status in [500, 502, 504, 404]) {
      test('$status : le serveur n’a pas pu ouvrir la session', () {
        final failure = of(http(status));
        expect(failure.code, 'http-$status');
        expect(
          failure.message,
          'Le serveur Carlys n’a pas pu ouvrir ta session. Réessaie dans un '
          'instant.',
        );
        expect(failure.severe, isTrue);
      });
    }
  });

  group('après le serveur', () {
    test('réponse illisible → appli-reponse', () {
      final failure = of(const MalformedResponseException('x'));
      expect(failure.code, 'appli-reponse');
      expect(failure.message, contains('n’a pas pu être lue'));
      expect(failure.reference, isNull);
    });

    test('réponse illisible de l’API : la réf. de son en-tête suit', () {
      final failure = of(
        const MalformedResponseException('x', requestId: '0badc0de-1234'),
      );
      expect(failure.code, 'appli-reponse');
      expect(
        failure.codeLine,
        'Code\u00A0: appli-reponse · réf.\u00A00badc0de',
      );
    });

    test('corps illisible décodé par Dio : appli-reponse, pas reseau-*', () {
      // La forme d'un JSON tronqué : l'échec naît DANS Dio, en `unknown`.
      final failure = of(
        transport(
          DioExceptionType.unknown,
          error: const FormatException('Unexpected end of input'),
        ),
      );
      expect(failure.code, 'appli-reponse');
    });

    test('jetons non enregistrés → appli-stockage', () {
      final failure = of(const StorageException('x'));
      expect(failure.code, 'appli-stockage');
      expect(failure.message, contains('enregistrer ta session'));
    });

    test('appareil non réclamé → appli-compte', () {
      final failure = of(const AccountClaimException('x'));
      expect(failure.code, 'appli-compte');
      expect(failure.message, contains('Ton compte n’a pas pu s’ouvrir'));
    });

    test('le filet garde un code : appli-inattendu', () {
      final failure = of(StateError('?'));
      expect(failure.code, 'appli-inattendu');
      expect(
        failure.message,
        'La connexion avec Google n’a pas abouti. Réessaie, ou utilise ton '
        'adresse e-mail.',
      );
    });
  });

  group('la ligne du code', () {
    test('sans référence', () {
      final failure = of(
        const SocialSignInUnavailable(
          google,
          SocialSignInObstacle.echec,
          code: 'google-failed_to_recover_auth',
        ),
      );
      // Une coupure possible, invisible (U+200B), après chaque souligné :
      // à 320 points et texte ×2, la ligne revient à la ligne entre deux
      // morceaux, jamais au milieu de l'un d'eux.
      expect(
        failure.codeLine,
        'Code\u00A0: google-failed_\u200Bto_\u200Brecover_\u200Bauth',
      );
      expect(
        failure.codeLine.replaceAll('\u200B', ''),
        'Code\u00A0: google-failed_to_recover_auth',
        reason: 'invisible : la ligne se lit comme le code',
      );
      // Ni « tiret » ni « souligné » à l'oreille.
      expect(failure.spokenCodeLine, 'Code : google failed to recover auth');
    });

    test('avec référence : huit caractères, épelés à l’oreille', () {
      final failure = of(http(500, message: 'x', requestId: '1a2b3c4d-5e6f'));
      expect(failure.codeLine, 'Code\u00A0: http-500 · réf.\u00A01a2b3c4d');
      expect(
        failure.spokenCodeLine,
        'Code : http 500, référence 1 a 2 b 3 c 4 d',
      );
    });
  });

  test('aucun texte affiché ne porte de tiret cadratin', () {
    final samples = <Object>[
      const SocialSignInUnavailable(
        google,
        SocialSignInObstacle.configuration,
        code: 'google-config-web',
      ),
      for (final obstacle in SocialSignInObstacle.values)
        SocialSignInUnavailable(google, obstacle, code: 'google-x'),
      for (final status in [400, 401, 403, 429, 500, 503])
        http(status, message: 'Refus.'),
      http(401, message: "Le fournisseur n'a pas transmis d'adresse."),
      for (final type in DioExceptionType.values)
        if (type != DioExceptionType.badResponse) transport(type),
      const MalformedResponseException('x'),
      const StorageException('x'),
      const AccountClaimException('x'),
      StateError('x'),
    ];
    for (final sample in samples) {
      final failure = of(sample);
      expect(failure.message, isNot(contains('—')), reason: failure.code);
      expect(failure.message, isNot(contains("'")), reason: failure.code);
      expect(failure.codeLine, isNot(contains('—')));
    }
  });

  test('chaque code fixe figure dans la table de diagnostic', () {
    // La liste est FERMÉE et DOCUMENTÉE : un code qui n'est pas dans la
    // table renvoie le propriétaire nulle part.
    final doc = File('../../docs/deployment/connexion-sociale.md');
    expect(doc.existsSync(), isTrue, reason: 'guide de mise en route absent');
    final table = doc.readAsStringSync();
    for (final code in [
      'google-config-web',
      'google-config-ios',
      'google-10',
      'google-7',
      'google-12500',
      'google-4',
      'google-sign_in_failed',
      'google-exception',
      'google-user_recoverable_auth',
      'google-failed_to_recover_auth',
      'google-sans-jeton',
      'google-plugin',
      'google-inattendu',
      'apple-plateforme',
      'apple-sans-jeton',
      'apple-plugin',
      'apple-inattendu',
      'reseau-delai',
      'reseau-connexion',
      'reseau-certificat',
      'reseau-inconnu',
      'http-401',
      'http-429',
      'http-503',
      'appli-reponse',
      'appli-stockage',
      'appli-compte',
      'appli-inattendu',
    ]) {
      expect(table, contains('`$code`'), reason: '$code absent de la doc');
    }
    // Les familles à partie variable ont chacune leur ligne générique.
    for (final family in [
      'google-<statut>',
      'google-<code>',
      'google-java-<classe>',
      'apple-<code>',
      'http-<statut>',
    ]) {
      expect(table, contains('`$family`'), reason: '$family absent');
    }
  });
}
