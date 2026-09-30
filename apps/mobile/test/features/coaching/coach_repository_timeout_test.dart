import 'dart:convert';
import 'dart:typed_data';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/coaching/data/coach_thread_cache.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le coach peut se taire longtemps avant son premier mot (il relit des
/// séances) : avec les 20 s de réception du client partagé, une réponse
/// lente s'afficherait « hors ligne » alors qu'elle arrive. Seul l'envoi d'un
/// message attend plus longtemps — ses en-têtes, que le premier battement du
/// serveur (`: ping`, toutes les 15 s) fait partir.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  /// Ce que la route en flux répondra : (statut, corps brut).
  (int, String) responses = (200, _sse(['delta', 'done']));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method != 'GET') return _stream(responses);
    return ResponseBody.fromString(
      jsonEncode({
        'data': const <Object>[],
        'meta': <String, Object?>{},
        'requestId': 't',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Un flux SSE comme l'API l'écrit, découpé octet par octet pour que le
/// lecteur prouve qu'il recolle les morceaux.
ResponseBody _stream((int, String) response) {
  final (status, body) = response;
  return ResponseBody(
    Stream.fromIterable(utf8.encode(body).map((b) => Uint8List.fromList([b]))),
    status,
    headers: {
      Headers.contentTypeHeader: [
        status == 200 ? 'text/event-stream' : Headers.jsonContentType,
      ],
    },
  );
}

String _sse(List<String> events) => events.map((event) {
  final data = switch (event) {
    'delta' => {'text': 'Répon'},
    'done' => {
      'data': {
        'userMessage': _message('m1', 'user'),
        'assistantMessage': _message('m2', 'assistant'),
        'remainingToday': 29,
      },
      'meta': <String, Object?>{},
      'requestId': 't',
    },
    _ => {
      'error': {
        'code': 'SERVICE_UNAVAILABLE',
        'message': 'Une erreur interne est survenue.',
        'details': <Object>[],
        'requestId': 'r-1',
      },
    },
  };
  return 'event: $event\ndata: ${jsonEncode(data)}\n\n';
}).join();

Map<String, Object?> _message(String id, String role) => {
  'id': id,
  'role': role,
  'content': 'Réponse',
};

void main() {
  late _RecordingAdapter adapter;
  late CoachRepositoryImpl repository;

  setUp(() {
    SharedPreferences.setMockInitialValues(
      {},
    ); // aucun propriétaire : rien de gardé
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(receiveTimeout: const Duration(seconds: 20)))
      ..httpClientAdapter = adapter;
    repository = CoachRepositoryImpl(dio, const CoachThreadCache());
  });

  test('l’envoi d’un message attend la réponse du coach 65 s', () async {
    await repository.sendMessage(
      conversationId: 'c1',
      messageId: 'm1',
      content: 'Séance jambes 30 min ?',
    );

    expect(adapter.requests.single.receiveTimeout, coachReplyTimeout);
    expect(coachReplyTimeout, const Duration(seconds: 65));
  });

  test('les autres appels gardent le délai du client partagé', () async {
    await repository.conversations();

    expect(adapter.requests.single.receiveTimeout, const Duration(seconds: 20));
  });

  group('réponse en flux', () {
    test(
      'en file : `queued` dit combien passent avant, `started` que c’est son tour',
      () async {
        adapter.responses = (
          200,
          'event: queued\ndata: {"ahead":2}\n\n'
              'event: queued\ndata: {"ahead":0}\n\n'
              'event: started\ndata: {}\n\n'
              '${_sse(['delta', 'done'])}',
        );
        final events = <String>[];

        await repository.sendMessage(
          conversationId: 'c1',
          messageId: 'm1',
          content: 'Séance jambes 30 min ?',
          onQueued: (ahead) => events.add('file:$ahead'),
          onStarted: () => events.add('tour'),
          onText: (text) => events.add('texte:$text'),
        );

        expect(events, ['file:2', 'file:0', 'tour', 'texte:Répon']);
      },
    );

    test(
      'file trop longue APRÈS l’attente : SERVICE_BUSY porté par l’erreur',
      () async {
        adapter.responses = (
          200,
          'event: queued\ndata: {"ahead":1}\n\n'
              'event: error\ndata: {"error":{"code":"SERVICE_BUSY","message":"Le coach est très sollicité.","details":[],"requestId":"r-2"}}\n\n',
        );

        await expectLater(
          repository.sendMessage(
            conversationId: 'c1',
            messageId: 'm1',
            content: 'Q ?',
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.code, 'code', 'SERVICE_BUSY')
                .having((e) => e.statusCode, 'statusCode', 503),
          ),
        );
      },
    );

    test(
      'les battements du serveur (`: ping`) passent sans rien dire',
      () async {
        adapter.responses = (
          200,
          ': ping\n\n${_sse(['delta'])}: ping\n\n: ping\n\n${_sse(['done'])}',
        );
        final seen = <String>[];

        final reply = await repository.sendMessage(
          conversationId: 'c1',
          messageId: 'm1',
          content: 'Séance jambes 30 min ?',
          onText: seen.add,
        );

        expect(seen, ['Répon']);
        expect(reply.assistantMessage.content, 'Réponse');
      },
    );

    test(
      'chaque morceau part à l’écran, la réplique archivée fait foi',
      () async {
        final seen = <String>[];
        final reply = await repository.sendMessage(
          conversationId: 'c1',
          messageId: 'm1',
          content: 'Séance jambes 30 min ?',
          onText: seen.add,
        );

        expect(
          adapter.requests.single.path,
          '/coach/conversations/c1/messages/stream',
        );
        expect(seen, ['Répon']);
        expect(reply.assistantMessage.content, 'Réponse');
        expect(reply.remainingToday, 29);
      },
    );

    test(
      'une panne en cours de route rend un 503, avec son identifiant',
      () async {
        adapter.responses = (200, _sse(['delta', 'error']));

        await expectLater(
          repository.sendMessage(
            conversationId: 'c1',
            messageId: 'm1',
            content: 'Q',
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statut', 503)
                .having((e) => e.requestId, 'requestId', 'r-1'),
          ),
        );
      },
    );

    test('un flux coupé avant la fin est une coupure réseau', () async {
      adapter.responses = (200, _sse(['delta']));

      await expectLater(
        repository.sendMessage(
          conversationId: 'c1',
          messageId: 'm1',
          content: 'Q',
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test(
      'un refus AVANT le flux garde son statut et son message (429)',
      () async {
        adapter.responses = (
          429,
          jsonEncode({
            'error': {
              'code': 'RATE_LIMITED',
              'message':
                  'Tu as atteint ta limite de messages pour aujourd’hui.',
              'details': <Object>[],
              'requestId': 'r-2',
            },
          }),
        );

        await expectLater(
          repository.sendMessage(
            conversationId: 'c1',
            messageId: 'm1',
            content: 'Q',
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statut', 429)
                .having((e) => e.message, 'message', contains('limite'))
                .having((e) => e.requestId, 'requestId', 'r-2'),
          ),
        );
      },
    );
  });
}
