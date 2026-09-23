import 'dart:convert';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/domain/entities/community_moderation.dart';
import 'package:carlys_mobile/features/community/domain/entities/friend_challenge.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE CONTRAT HTTP d'un défi entre amis, vu du mobile : la lecture du
/// détail, la création avec son mot, le signalement sous le nom du
/// créateur — et la lecture tolérante d'un serveur plus ancien.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Map<String, Object?> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, Object?> _enveloppe(Object? data) => {
  'data': data,
  'meta': <String, Object?>{},
  'requestId': 'test',
};

Map<String, Object?> _defi({bool avecChampsRecents = true}) => {
  'id': 'defi-1',
  'title': 'Cinq séances cette semaine',
  'metric': 'WORKOUTS',
  'unit': 'séances',
  'target': 5,
  'status': 'OPEN',
  'startsAt': '2026-09-23T07:00:00.000Z',
  'endsAt': '2026-09-30T07:00:00.000Z',
  'creatorDisplayName': 'Léa',
  'myStatus': 'INVITED',
  if (avecChampsRecents) ...{
    'message': 'Allez on y va !',
    'createdAt': '2026-09-23T06:24:00.000Z',
    'durationDays': 7,
  },
  'members': [
    {
      'userId': 'u-lea',
      'displayName': 'Léa',
      'status': 'ACCEPTED',
      'contribution': 2,
      'rank': 1,
      'isMe': false,
      if (avecChampsRecents) 'isCreator': true,
    },
    {
      'userId': 'u-moi',
      'displayName': 'Camille',
      'status': 'INVITED',
      'contribution': 0,
      'rank': null,
      'isMe': true,
      if (avecChampsRecents) 'isCreator': false,
    },
  ],
};

void main() {
  late Dio dio;
  late CommunityRepositoryImpl repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
    repository = CommunityRepositoryImpl(dio);
  });

  _RecordingAdapter record(ResponseBody Function(RequestOptions) respond) {
    final adapter = _RecordingAdapter(respond);
    dio.httpClientAdapter = adapter;
    return adapter;
  }

  test(
    'le détail se lit par son identifiant, message et créateur compris',
    () async {
      final adapter = record((_) => _json(200, _enveloppe(_defi())));

      final defi = await repository.friendChallenge('defi-1');

      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.path,
        '/community/friend-challenges/defi-1',
      );
      expect(defi.message, 'Allez on y va !');
      expect(defi.createdAt, DateTime.utc(2026, 9, 23, 6, 24));
      expect(defi.durationDays, 7);
      expect(defi.creator?.displayName, 'Léa');
      // Les participants : les acceptés et les invités.
      expect(defi.participants, hasLength(2));
    },
  );

  test('un serveur plus ancien : pas de message, pas de créateur, rien ne '
      'casse', () async {
    record((_) => _json(200, _enveloppe(_defi(avecChampsRecents: false))));

    final defi = await repository.friendChallenge('defi-1');

    expect(defi.message, isNull);
    expect(defi.createdAt, isNull);
    expect(defi.durationDays, isNull);
    expect(defi.creator, isNull);
  });

  test('un message blanc se lit comme absent', () async {
    record((_) => _json(200, _enveloppe({..._defi(), 'message': '   '})));

    expect((await repository.friendChallenge('defi-1')).message, isNull);
  });

  test('un défi qui n’est plus le mien : 404, sans deviner pourquoi', () async {
    record(
      (_) => _json(404, {
        'error': {
          'code': 'NOT_FOUND',
          'message': 'Défi introuvable.',
          'details': null,
          'requestId': 'test',
        },
      }),
    );

    await expectLater(
      repository.friendChallenge('defi-perdu'),
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('la création porte le mot, et le tait quand il est absent', () async {
    final adapter = record((_) => _json(201, _enveloppe(_defi())));

    await repository.createFriendChallenge(
      'defi-1',
      const NewFriendChallenge(
        title: 'Cinq séances cette semaine',
        metric: ChallengeMetric.workouts,
        durationDays: 7,
        target: 5,
        invitedUserIds: ['u-lea'],
        message: 'Allez on y va !',
      ),
    );
    await repository.createFriendChallenge(
      'defi-2',
      const NewFriendChallenge(
        title: 'Qui court le plus',
        metric: ChallengeMetric.distanceMeters,
        durationDays: 7,
        invitedUserIds: ['u-lea'],
      ),
    );

    final avecMot = adapter.requests.first.data as Map<String, Object?>;
    final sansMot = adapter.requests.last.data as Map<String, Object?>;
    expect(avecMot['message'], 'Allez on y va !');
    expect(sansMot.containsKey('message'), isFalse);
  });

  test(
    'signaler un défi : sous le nom de son CRÉATEUR, avec le défi visé',
    () async {
      final lecture = record((_) => _json(200, _enveloppe(_defi())));
      final defi = await repository.friendChallenge('defi-1');
      expect(lecture.requests, hasLength(1));

      final adapter = record(
        (_) => _json(201, _enveloppe(<String, Object?>{})),
      );
      await repository.reportFriendChallenge(
        defi,
        CommunityReportDraft(
          reason: CommunityReportReason.inappropriateContent,
        ),
      );

      expect(adapter.requests.single.path, '/community/reports');
      expect(adapter.requests.single.data, {
        'reportedUserId': 'u-lea',
        'friendChallengeId': 'defi-1',
        'reason': 'CONTENU_INAPPROPRIE',
      });
    },
  );

  test('sans créateur connu, rien n’est envoyé', () async {
    record((_) => _json(200, _enveloppe(_defi(avecChampsRecents: false))));
    final defi = await repository.friendChallenge('defi-1');
    final adapter = record((_) => _json(201, _enveloppe(<String, Object?>{})));

    expect(
      () => repository.reportFriendChallenge(
        defi,
        CommunityReportDraft(reason: CommunityReportReason.spam),
      ),
      throwsStateError,
    );
    expect(adapter.requests, isEmpty);
  });
}
