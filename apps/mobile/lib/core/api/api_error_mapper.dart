import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Convertit les erreurs Dio (et l'enveloppe d'erreur de l'API Carlys)
/// vers la hiérarchie AppException du domaine.
AppException mapDioException(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return NetworkException(
        'Serveur injoignable',
        cause: exception,
        stackTrace: exception.stackTrace,
      );
    case DioExceptionType.badResponse:
      return _mapResponse(exception);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return UnknownException(
        exception.message ?? 'Erreur réseau inattendue',
        cause: exception,
        stackTrace: exception.stackTrace,
      );
  }
}

AppException _mapResponse(DioException exception) {
  final statusCode = exception.response?.statusCode ?? 0;
  final envelope = _errorEnvelopeOf(exception.response?.data);
  final message =
      envelope?.message ?? 'Le serveur a répondu avec une erreur ($statusCode)';

  if (statusCode == 401) {
    return UnauthorizedException(message, cause: exception);
  }
  if (statusCode == 403) {
    return ForbiddenException(message, cause: exception);
  }
  if (statusCode == 400 || statusCode == 409 || statusCode == 422) {
    return ValidationException(
      message,
      fieldErrors: envelope?.fieldErrors ?? const {},
      cause: exception,
    );
  }
  return ServerException(message, statusCode: statusCode, cause: exception);
}

class _ErrorEnvelope {
  const _ErrorEnvelope(this.message, this.fieldErrors);

  final String message;
  final Map<String, String> fieldErrors;
}

/// Enveloppe d'erreur Carlys : { error: { code, message, details, requestId } }.
_ErrorEnvelope? _errorEnvelopeOf(Object? body) {
  if (body is! Map<String, dynamic>) return null;
  final error = body['error'];
  if (error is! Map<String, dynamic>) return null;

  final message = error['message'];
  final details = error['details'];
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
  return message is String ? _ErrorEnvelope(message, fieldErrors) : null;
}
