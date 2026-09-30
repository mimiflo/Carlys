import 'dart:convert';
import 'dart:io' show IOException;

import 'package:dio/dio.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/sse_events.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/coach.dart';
import '../dto/coach_dtos.dart';

/// Lit la réponse EN FLUX du coach (`…/messages/stream`) : chaque `delta`
/// part à [onText], `done` rend la réplique archivée, `error` lève la même
/// exception qu'un refus ordinaire.
///
/// Un flux qui s'arrête SANS `done` est une coupure : le serveur, lui, finit
/// son tour et l'archive — renvoyer la même question la rendra.
Future<CoachReply> readCoachReplyStream(
  Response<ResponseBody> response,
  void Function(String text)? onText,
) async {
  final requestId = requestIdOf(response.headers);
  final body = response.data;
  if (body == null) {
    throw MalformedResponseException(
      'Flux du coach vide',
      requestId: requestId,
    );
  }
  try {
    await for (final sse in sseEvents(body.stream)) {
      final data = jsonDecode(sse.data) as Map<String, dynamic>;
      switch (sse.event) {
        case 'delta':
          onText?.call(data['text'] as String? ?? '');
        case 'done':
          return coachReplyFromJson(
            data['data'] as Map<String, dynamic>? ?? const {},
          );
        case 'error':
          throw _streamError(data, requestId);
      }
    }
  } on FormatException catch (error, stack) {
    throw MalformedResponseException(
      'Flux du coach illisible',
      requestId: requestId,
      cause: error,
      stackTrace: stack,
    );
  } on TypeError catch (error, stack) {
    throw MalformedResponseException(
      'Flux du coach illisible',
      requestId: requestId,
      cause: error,
      stackTrace: stack,
    );
  } on IOException catch (error, stack) {
    throw _cut(error, stack);
  }
  throw _cut(null, null);
}

/// Le corps d'une réponse d'ERREUR demandée en flux arrive, lui aussi, en
/// flux : on le lit avant de le confier au traducteur commun, pour que le
/// statut ET le message de l'enveloppe survivent.
Future<DioException> withReadableBody(DioException exception) async {
  final response = exception.response;
  final data = response?.data;
  if (response == null || data is! ResponseBody) return exception;
  try {
    final text = await utf8.decoder.bind(data.stream).join();
    response.data = text.isEmpty ? null : jsonDecode(text);
  } on Object {
    // Corps illisible (page d'un proxy) : le statut seul parlera.
    response.data = null;
  }
  return exception;
}

ServerException _streamError(Map<String, dynamic> body, String? requestId) {
  final error = body['error'] as Map<String, dynamic>? ?? const {};
  return ServerException(
    error['message'] as String? ?? 'Le coach n’a pas pu répondre',
    statusCode: _statusOf[error['code']] ?? 500,
    requestId: error['requestId'] as String? ?? requestId,
    fromApi: true,
  );
}

/// Le statut HTTP qu'aurait eu l'erreur si elle était arrivée avant le flux.
const _statusOf = {
  'SERVICE_UNAVAILABLE': 503,
  'RATE_LIMITED': 429,
  'CONFLICT': 409,
  'NOT_FOUND': 404,
  'FORBIDDEN': 403,
};

NetworkException _cut(Object? cause, StackTrace? stack) => NetworkException(
  'Réponse du coach coupée',
  transport: TransportFailure.cut,
  cause: cause,
  stackTrace: stack,
);
