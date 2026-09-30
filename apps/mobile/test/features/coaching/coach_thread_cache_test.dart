import 'dart:convert';
import 'dart:typed_data';

import 'package:carlys_mobile/core/database/local_account_owner.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/features/coaching/data/coach_thread_cache.dart';
import 'package:carlys_mobile/features/coaching/data/repositories/coach_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _message(String id, String role, String content) => {
  'id': id,
  'role': role,
  'content': content,
};

/// Rend le fil sur GET, un flux SSE terminé sur POST.
class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode({
          'data': {
            'id': 'fil-1',
            'title': 'Squats',
            'messages': [_message('m1', 'USER', 'Et mes squats ?')],
          },
          'meta': <String, Object?>{},
          'requestId': 't',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final done = {
      'data': {
        'userMessage': _message('m2', 'USER', 'Et le dos ?'),
        'assistantMessage': _message('m3', 'ASSISTANT', 'Gainage.'),
        'remainingToday': 28,
      },
    };
    return ResponseBody(
      Stream.value(
        Uint8List.fromList(
          utf8.encode('event: done\ndata: ${jsonEncode(done)}\n\n'),
        ),
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Le dernier fil du coach, gardé pour être relu sans réseau.
void main() {
  const cache = CoachThreadCache();

  setUp(
    () => SharedPreferences.setMockInitialValues({
      LocalAccountOwner.key: 'compte-a',
    }),
  );

  test('rien de gardé : rien à relire', () async {
    expect(await cache.read(), isNull);
  });

  test('le fil gardé se relit tel que le serveur l’a rendu', () async {
    await cache.save({
      'id': 'fil-1',
      'title': 'Squats',
      'messages': [_message('m1', 'USER', 'Et mes squats ?')],
    });

    final fil = await cache.read();

    expect(fil?.id, 'fil-1');
    expect(fil?.title, 'Squats');
    expect(fil?.messages.single.content, 'Et mes squats ?');
  });

  test('un échange s’ajoute au MÊME fil', () async {
    await cache.save({
      'id': 'fil-1',
      'title': 'Squats',
      'messages': [_message('m1', 'USER', 'Et mes squats ?')],
    });

    await cache.append('fil-1', [_message('m2', 'ASSISTANT', 'Une série.')]);

    final fil = await cache.read();
    expect(fil?.title, 'Squats');
    expect(fil?.messages.map((m) => m.id), ['m1', 'm2']);
  });

  test('le premier échange d’un fil NEUF remplace l’ancien', () async {
    await cache.save({
      'id': 'fil-1',
      'messages': [_message('m1', 'USER', 'Ancien')],
    });

    await cache.append('fil-2', [_message('m9', 'USER', 'Nouveau')]);

    final fil = await cache.read();
    expect(fil?.id, 'fil-2');
    expect(fil?.messages.map((m) => m.id), ['m9']);
  });

  test('une copie abîmée vaut « rien de gardé », sans planter', () async {
    SharedPreferences.setMockInitialValues({
      LocalAccountOwner.key: 'compte-a',
      CoachThreadCache.key:
          '{"owner": "compte-a", "id": "fil-1", "messages": [{"id": 3}]}',
    });
    expect(await cache.read(), isNull);

    SharedPreferences.setMockInitialValues({
      LocalAccountOwner.key: 'compte-a',
      CoachThreadCache.key: 'pas du',
    });
    expect(await cache.read(), isNull);
  });

  // Une réponse en flux peut finir APRÈS la purge (déconnexion pendant que
  // le coach écrit) : son échange ne doit pas renaître pour le compte suivant,
  // que la purge n'aurait plus aucune raison d'effacer.
  test('un échange arrivé après la purge n’est pas gardé', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LocalAccountOwner.key);

    await cache.append('fil-1', [_message('m1', 'USER', 'Mon genou')]);

    expect(prefs.containsKey(CoachThreadCache.key), isFalse);
    expect(await cache.read(), isNull);
  });

  test('la copie d’un AUTRE compte ne se relit pas', () async {
    await cache.save({
      'id': 'fil-1',
      'messages': [_message('m1', 'USER', 'Mon genou')],
    });
    await const LocalAccountOwner().write('compte-b');

    expect(await cache.read(), isNull);
  });

  test('une proposition lancée est notée dans la copie', () async {
    await cache.save({
      'id': 'fil-1',
      'messages': [
        {
          ..._message('m1', 'ASSISTANT', 'Tiens.'),
          'proposal': {
            'id': 'p-1',
            'name': 'Haut du corps',
            'estimatedMinutes': 25,
            'items': <Object>[],
          },
        },
      ],
    });

    await cache.markAccepted('p-1', 'seance-1');

    final fil = await cache.read();
    expect(fil?.messages.single.proposal?.acceptedSessionId, 'seance-1');
  });

  test('un programme créé est noté dans la copie', () async {
    await cache.save({
      'id': 'fil-1',
      'messages': [
        {
          ..._message('m1', 'ASSISTANT', 'Trois séances.'),
          'programProposal': {
            'id': 'pp-1',
            'goal': 'STRENGTH',
            'weeklySessions': 3,
            'sessionMinutes': 45,
            'acceptedProgramId': null,
          },
        },
      ],
    });

    await cache.markProgramAccepted('pp-1', 'prog-1');

    final fil = await cache.read();
    expect(fil?.messages.single.programProposal?.acceptedProgramId, 'prog-1');
  });

  test('seuls les derniers messages sont gardés, sans doublon', () async {
    final beaucoup = [
      for (var i = 0; i < CoachThreadCache.maxMessages + 5; i++)
        _message('m$i', 'USER', 'Question $i'),
    ];
    await cache.save({'id': 'fil-1', 'messages': beaucoup});
    await cache.append('fil-1', [beaucoup.last]);

    final fil = await cache.read();
    expect(fil?.messages, hasLength(CoachThreadCache.maxMessages));
    expect(fil?.messages.last.id, beaucoup.last['id']);
  });

  test('une copie abîmée ne fait pas échouer l’envoi en ligne', () async {
    SharedPreferences.setMockInitialValues({
      LocalAccountOwner.key: 'compte-a',
      CoachThreadCache.key:
          '{"owner": "compte-a", "id": "fil-1", '
          '"messages": "pas une liste"}',
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = _Adapter();

    final reply = await CoachRepositoryImpl(dio, cache).sendMessage(
      conversationId: 'fil-1',
      messageId: 'm2',
      content: 'Et le dos ?',
    );

    expect(reply.assistantMessage.content, 'Gainage.');
  });

  test('la copie appartient au compte : la purge l’emporte', () {
    expect(
      DriftLocalAccountPurge.accountOwnedPreferenceKeys,
      contains(CoachThreadCache.key),
    );
  });

  test('le dépôt garde le fil relu, puis chaque échange terminé', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = _Adapter();
    final repository = CoachRepositoryImpl(dio, cache);

    await repository.conversation('fil-1');
    await repository.sendMessage(
      conversationId: 'fil-1',
      messageId: 'm2',
      content: 'Et le dos ?',
    );

    final fil = await repository.offlineConversation();
    expect(fil?.title, 'Squats');
    expect(fil?.messages.map((m) => m.content), [
      'Et mes squats ?',
      'Et le dos ?',
      'Gainage.',
    ]);
  });
}
