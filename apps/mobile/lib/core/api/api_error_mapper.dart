import 'dart:io'
    show HttpException, IOException, OSError, SocketException, TlsException;

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
      // fausse, réseau qui intercepte le TLS). AVANT les E/S : une
      // `TlsException` en est une.
      if (cause is TlsException) {
        return _unknown(exception, TransportFailure.certificate);
      }
      // Tout le reste des E/S qui arrive ici a suivi une connexion ÉTABLIE :
      // l'échec de la connexion elle-même, Dio le classe en `connectionError`
      // ou `connectionTimeout`. Le détail sépare, sur la popup, un
      // intermédiaire qui coupe (104) d'une réponse perdue en route (corps).
      if (cause is IOException || cause is OSError) {
        return _unknown(
          exception,
          TransportFailure.cut,
          detail: _cutDetail(cause!),
        );
      }
      // Une exception LOCALE levée avant tout envoi (un intercepteur, le
      // trousseau…) : ce n'est pas le réseau, et le dire enverrait chercher
      // au mauvais endroit.
      if (cause != null) {
        return UnknownException(
          exception.message ?? 'Erreur inattendue avant l’envoi',
          cause: exception,
          stackTrace: exception.stackTrace,
        );
      }
      return _unknown(exception, TransportFailure.other);
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

UnknownException _unknown(
  DioException exception,
  TransportFailure how, {
  String? detail,
}) => UnknownException(
  exception.message ?? 'Erreur réseau inattendue',
  transport: how,
  transportDetail: detail,
  cause: exception,
  stackTrace: exception.stackTrace,
);

/// Ce qui a rompu une connexion établie, en un mot STABLE d'une plateforme
/// à l'autre : le même RST vaut 104 sous Android et 54 sous iOS, et
/// `dart:io` ré-enveloppe l'erreur d'une LECTURE en `HttpException` qui n'en
/// garde que le texte. `reset` : remise à zéro par un intermédiaire ;
/// `abandon` : connexion abandonnée par le téléphone ; `tube` : écriture
/// sur une connexion fermée ; `delai` : délai du noyau ; `corps` : réponse
/// commencée puis coupée. Un numéro d'erreur que la table ne connaît pas
/// reste un numéro. Ces textes ne sont pas un contrat du SDK : s'ils
/// changent, le détail retombe sur `http`, moins précis, jamais faux.
String _cutDetail(Object cause) {
  final osError = switch (cause) {
    SocketException(:final osError) => osError,
    OSError() => cause,
    _ => null,
  };
  if (osError != null && osError.errorCode > 0) {
    return switch (osError.errorCode) {
      104 || 54 => 'reset',
      103 || 53 => 'abandon',
      32 => 'tube',
      110 || 60 => 'delai',
      final code => '$code',
    };
  }
  if (cause is SocketException) return 'socket';
  final text = (cause is HttpException ? cause.message : '$cause')
      .toLowerCase();
  for (final (needle, detail) in const [
    ('while receiving data', 'corps'),
    ('full body', 'corps'),
    ('reset by peer', 'reset'),
    ('connection abort', 'abandon'),
    ('broken pipe', 'tube'),
    ('timed out', 'delai'),
    ('read failed', 'lecture'),
    ('write failed', 'ecriture'),
  ]) {
    if (text.contains(needle)) return detail;
  }
  return 'http';
}

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
