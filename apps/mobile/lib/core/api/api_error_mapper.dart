import 'dart:io' show TlsException;

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// En-tête qui porte l'identifiant de requête du serveur — le
/// `REQUEST_ID_HEADER` de `packages/shared-config`, que l'API pose sur CHAQUE
/// réponse (`genReqId` d'`app.module.ts`).
const String requestIdHeader = 'x-request-id';

/// Forme d'un identifiant de requête que l'API accepte (`REQUEST_ID_PATTERN`
/// d'`app.module.ts`). Ce qui n'a pas cette forme n'en est pas un — un
/// proxy intermédiaire, une page d'erreur — et n'est pas retenu : rien de
/// libre venu du réseau n'arrive jusqu'à l'écran.
final RegExp _requestIdShape = RegExp(r'^[\w-]{1,64}$');

/// Convertit les erreurs Dio (et l'enveloppe d'erreur de l'API Carlys)
/// vers la hiérarchie AppException du domaine.
AppException mapDioException(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return _network(exception, TransportFailure.timeout);
    case DioExceptionType.connectionError:
      return _network(exception, TransportFailure.connection);
    case DioExceptionType.badResponse:
      return _mapResponse(exception);
    case DioExceptionType.badCertificate:
      return _unknown(exception, TransportFailure.certificate);
    case DioExceptionType.unknown:
      // Une réponse 2xx dont le corps ne se lit pas échoue DANS Dio, avant
      // que l'appelant ne le voie : JSON tronqué (`FormatException` du
      // décodeur), corps d'un autre type que celui demandé (`TypeError` du
      // `response.data as T` d'`assureResponse`). Dio les enveloppe en
      // `unknown`, comme une coupure. Or un hôte qui a RÉPONDU n'est pas
      // injoignable : le dire enverrait vérifier le réseau alors que c'est
      // ce qui répond (portail, proxy, adresse d'API qui pointe ailleurs)
      // qu'il faut regarder.
      final cause = exception.error;
      if (cause is FormatException || cause is TypeError) {
        return MalformedResponseException(
          'Réponse du serveur illisible',
          requestId: requestIdOf(exception.response?.headers),
          cause: exception,
          stackTrace: exception.stackTrace,
        );
      }
      // Un certificat que le système refuse n'arrive PAS en `badCertificate`
      // (réservé au rappel `validateCertificate`, que l'application n'arme
      // pas) : l'adaptateur d'E/S de Dio laisse filer la `HandshakeException`,
      // qu'il enveloppe alors en `unknown`. C'est pourtant, sur un vrai
      // téléphone, LA forme d'un échec de certificat (date du téléphone
      // fausse, réseau qui intercepte le TLS).
      return _unknown(
        exception,
        exception.error is TlsException
            ? TransportFailure.certificate
            : TransportFailure.other,
      );
    case DioExceptionType.cancel:
      return _unknown(exception, TransportFailure.other);
  }
}

NetworkException _network(DioException exception, TransportFailure how) =>
    NetworkException(
      'Serveur injoignable',
      transport: how,
      cause: exception,
      stackTrace: exception.stackTrace,
    );

UnknownException _unknown(DioException exception, TransportFailure how) =>
    UnknownException(
      exception.message ?? 'Erreur réseau inattendue',
      transport: how,
      cause: exception,
      stackTrace: exception.stackTrace,
    );

AppException _mapResponse(DioException exception) {
  final response = exception.response;
  final statusCode = response?.statusCode ?? 0;
  final envelope = _errorEnvelopeOf(response?.data);
  final message =
      envelope?.message ?? 'Le serveur a répondu avec une erreur ($statusCode)';
  // L'enveloppe d'abord : c'est elle que le filtre d'erreurs de l'API écrit,
  // avec l'identifiant même de la ligne de journal. L'en-tête ensuite : il
  // existe aussi quand le corps n'est pas une enveloppe.
  final requestId =
      _validRequestId(envelope?.requestId) ?? requestIdOf(response?.headers);
  final fromApi = envelope != null;

  if (statusCode == 401) {
    return UnauthorizedException(
      message,
      statusCode: statusCode,
      requestId: requestId,
      fromApi: fromApi,
      cause: exception,
    );
  }
  if (statusCode == 403) {
    return ForbiddenException(
      message,
      statusCode: statusCode,
      requestId: requestId,
      fromApi: fromApi,
      cause: exception,
    );
  }
  if (statusCode == 400 || statusCode == 409 || statusCode == 422) {
    return ValidationException(
      message,
      fieldErrors: envelope?.fieldErrors ?? const {},
      statusCode: statusCode,
      requestId: requestId,
      fromApi: fromApi,
      cause: exception,
    );
  }
  return ServerException(
    message,
    statusCode: statusCode,
    requestId: requestId,
    fromApi: fromApi,
    cause: exception,
  );
}

/// L'identifiant de requête que porte l'en-tête [requestIdHeader] d'une
/// réponse, s'il en a la forme.
///
/// Ne JETTE jamais : c'est ce convertisseur qui transforme une panne en
/// `AppException`, il ne peut pas en ajouter une. D'où la liste, et non
/// `Headers.value`, qui lève dès que l'en-tête est répété (l'API en pose un,
/// un proxy de corrélation peut en ajouter un second). La première valeur
/// est celle de l'amont : un proxy ajoute ses en-têtes APRÈS ceux qu'il
/// relaie.
String? requestIdOf(Headers? headers) =>
    _validRequestId(headers?[requestIdHeader]?.firstOrNull);

String? _validRequestId(String? raw) =>
    raw != null && _requestIdShape.hasMatch(raw) ? raw : null;

class _ErrorEnvelope {
  const _ErrorEnvelope(this.message, this.fieldErrors, this.requestId);

  final String message;
  final Map<String, String> fieldErrors;
  final String? requestId;
}

/// Enveloppe d'erreur Carlys : { error: { code, message, details, requestId } }.
_ErrorEnvelope? _errorEnvelopeOf(Object? body) {
  if (body is! Map<String, dynamic>) return null;
  final error = body['error'];
  if (error is! Map<String, dynamic>) return null;

  final message = error['message'];
  final details = error['details'];
  final requestId = error['requestId'];
  final fieldErrors = <String, String>{};
  if (details is List) {
    for (final (index, detail) in details.indexed) {
      if (detail is Map<String, dynamic> && detail['message'] is String) {
        final field = detail['field'];
        fieldErrors[field is String ? field : '$index'] =
            detail['message'] as String;
      }
    }
  }
  return message is String
      ? _ErrorEnvelope(
          message,
          fieldErrors,
          requestId is String ? requestId : null,
        )
      : null;
}
