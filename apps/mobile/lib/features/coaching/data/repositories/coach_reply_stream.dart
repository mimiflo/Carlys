import 'dart:convert';
import 'dart:io' show IOException;

import 'package:dio/dio.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/sse_events.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coach_thread_state.dart';
import '../dto/coach_dtos.dart';

/// Lit la réponse EN FLUX du coach (`…/messages/stream`) : `queued` dit à
/// [onQueued] combien de demandes passent avant, `started` à [onStarted] que
/// c'est son tour, chaque `step` puis `stepDone` (une étape de sa réflexion
/// qui commence, puis qui finit) à [onStep],
/// chaque `delta` part à [onText], `done` rend la réplique
/// archivée (son JSON passe d'abord par [onDone]), `error` lève la même
/// exception qu'un refus ordinaire. Un évènement inconnu est ignoré : le
/// serveur peut en ajouter sans casser les versions installées.
///
/// Un flux qui s'arrête SANS `done` est une coupure : le serveur, lui, finit
/// son tour et l'archive — renvoyer la même question la rendra.
Future<CoachReply> readCoachReplyStream(
  Response<ResponseBody> response,
  void Function(String text)? onText, {
  Future<void> Function(Map<String, dynamic> json)? onDone,
  void Function(int ahead)? onQueued,
  void Function()? onStarted,
  void Function(CoachStep step)? onStep,
}) async {
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
        case 'queued':
          onQueued?.call((data['ahead'] as num?)?.toInt() ?? 0);
        case 'started':
          onStarted?.call();
        case 'step' || 'stepDone':
          final label = data['label'];
          final elapsed = (data['elapsedMs'] as num?)?.toInt();
          if (label is String) {
            onStep?.call((
              label: label,
              done: sse.event == 'stepDone',
              elapsed: elapsed == null ? null : Duration(milliseconds: elapsed),
            ));
          }
        case 'delta':
          onText?.call(data['text'] as String? ?? '');
        case 'done':
          final json = data['data'] as Map<String, dynamic>? ?? const {};
          final reply = coachReplyFromJson(json);
          await onDone?.call(json);
          return reply;
        case 'error':
          throw _streamError(data, requestId);
      }
    }
  } on IOException catch (error, stack) {
    throw _cut(error, stack);
  } catch (error, stack) {
    // JSON illisible, ou d'une forme inattendue : la même panne.
    if (error is! FormatException && error is! TypeError) rethrow;
    throw MalformedResponseException(
      'Flux du coach illisible',
      requestId: requestId,
      cause: error,
      stackTrace: stack,
    );
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
    code: error['code'] as String?,
    statusCode: _statusOf[error['code']] ?? 500,
    requestId: error['requestId'] as String? ?? requestId,
    fromApi: true,
  );
}

/// Le statut HTTP qu'aurait eu l'erreur si elle était arrivée avant le flux.
const _statusOf = {
  'SERVICE_UNAVAILABLE': 503,
  'SERVICE_BUSY': 503,
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
