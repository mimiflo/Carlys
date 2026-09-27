import 'dart:convert';

import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le coach met jusqu'à 50 s à répondre (échéance du tour côté serveur,
/// `COACH_TURN_DEADLINE_MS`) : avec les 20 s de réception du client
/// partagé, une réponse lente s'afficherait « hors ligne » alors qu'elle
/// arrive. Seul l'envoi d'un message attend plus longtemps.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Object data = options.method == 'GET'
        ? const <Object>[]
        : {
            'userMessage': _message('m1', 'user'),
            'assistantMessage': _message('m2', 'assistant'),
            'remainingToday': 29,
          };
    return ResponseBody.fromString(
      jsonEncode({'data': data, 'meta': <String, Object?>{}, 'requestId': 't'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _message(String id, String role) => {
  'id': id,
  'role': role,
  'content': 'Réponse',
};

void main() {
  late _RecordingAdapter adapter;
  late CoachRepositoryImpl repository;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(receiveTimeout: const Duration(seconds: 20)))
      ..httpClientAdapter = adapter;
    repository = CoachRepositoryImpl(dio);
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
}
