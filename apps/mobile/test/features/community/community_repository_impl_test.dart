import 'dart:convert';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/domain/entities/community.dart';
import 'package:carlys_mobile/features/community/domain/entities/community_moderation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptateur HTTP factice : enregistre chaque requête et rejoue la réponse
/// préparée, pour figer le CONTRAT des routes de protection (chemins,
/// verbes, charges utiles, 204 sans corps) sans serveur.
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

ResponseBody _noContent() => ResponseBody.fromString('', 204);

ResponseBody _json(int statusCode, Map<String, Object?> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

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

  final encouragement = Encouragement(
    id: '11111111-1111-4111-8111-111111111111',
    fromUserId: '22222222-2222-4222-8222-222222222222',
    fromName: 'Sarah',
    message: 'Continue !',
    sentAt: DateTime.utc(2026, 9, 1),
  );

  test(
    'retirer un ami : DELETE /community/friends/:id, 204 sans corps',
    () async {
      final adapter = record((_) => _noContent());

      await repository.removeFriend('ami-1');

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/community/friends/ami-1');
    },
  );

  test(
    'bloquer / débloquer : POST puis DELETE /community/blocks/:id',
    () async {
      final adapter = record((_) => _noContent());

      await repository.blockUser('ami-1');
      await repository.unblockUser('ami-1');

      expect(adapter.requests.map((r) => r.method), ['POST', 'DELETE']);
      expect(adapter.requests.map((r) => r.path).toSet(), {
        '/community/blocks/ami-1',
      });
    },
  );

  test('personnes bloquées : lues, dernier blocage d’abord', () async {
    record(
      (_) => _json(200, {
        'data': [
          {
            'userId': 'u-ancien',
            'displayName': 'Tom',
            'blockedAt': '2026-08-01T10:00:00.000Z',
          },
          {
            'userId': 'u-recent',
            'displayName': 'Nina',
            'blockedAt': '2026-09-01T10:00:00.000Z',
          },
        ],
        'meta': <String, Object?>{},
        'requestId': 'test',
      }),
    );

    final blocked = await repository.listBlocked();

    expect(blocked.map((b) => b.userId), ['u-recent', 'u-ancien']);
    expect(blocked.first.displayName, 'Nina');
    expect(blocked.first.blockedAt, DateTime.utc(2026, 9, 1, 10));
  });

  test(
    'retirer un encouragement : DELETE /community/encouragements/:id',
    () async {
      final adapter = record((_) => _noContent());

      await repository.deleteEncouragement(encouragement.id);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/community/encouragements/${encouragement.id}');
    },
  );

  test('signaler une personne : motif serveur, sans encouragementId', () async {
    final adapter = record((_) => _json(201, {'data': {}}));

    await repository.reportUser(
      'u-1',
      CommunityReportDraft(
        reason: CommunityReportReason.harassment,
        details: '  Messages insistants.  ',
      ),
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/community/reports');
    expect(request.data, {
      'reportedUserId': 'u-1',
      'reason': 'HARCELEMENT',
      'details': 'Messages insistants.',
    });
  });

  test('signaler un message : sous le nom de son AUTEUR, précisions vides '
      'omises', () async {
    final adapter = record((_) => _json(201, {'data': {}}));

    await repository.reportEncouragement(
      encouragement,
      CommunityReportDraft(
        reason: CommunityReportReason.inappropriateContent,
        details: '   ',
      ),
    );

    expect(adapter.requests.single.data, {
      'reportedUserId': encouragement.fromUserId,
      'encouragementId': encouragement.id,
      'reason': 'CONTENU_INAPPROPRIE',
    });
  });

  test(
    'le fil porte l’auteur de chaque mot, pour pouvoir le signaler',
    () async {
      record(
        (_) => _json(200, {
          'data': [
            {
              'id': encouragement.id,
              'fromUserId': encouragement.fromUserId,
              'fromDisplayName': 'Sarah',
              'message': 'Continue !',
              'sentAt': '2026-09-01T00:00:00.000Z',
            },
          ],
          'meta': <String, Object?>{},
          'requestId': 'test',
        }),
      );

      final feed = await repository.encouragements();

      expect(feed.single.fromUserId, encouragement.fromUserId);
      expect(feed.single.fromName, 'Sarah');
    },
  );

  test('réseau mort : NetworkException, pas une panne serveur', () async {
    record((options) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'hors ligne (voulu par le test)',
      );
    });

    await expectLater(
      repository.blockUser('u-1'),
      throwsA(isA<NetworkException>()),
    );
  });
}
