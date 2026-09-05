import 'dart:convert';

import 'package:carlys_mobile/core/auth/token_refresher.dart';
import 'package:carlys_mobile/core/auth/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_secure_storage.dart';

/// Adaptateur HTTP factice : rejoue des réponses préparées et compte les appels.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    return _handler(options);
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

void main() {
  late TokenStorage storage;
  late Dio dio;

  setUp(() {
    storage = TokenStorage(FakeSecureStorage());
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
  });

  test('sans refresh token local : aucun appel réseau', () async {
    final adapter = _FakeAdapter((_) async => _json(200, {}));
    dio.httpClientAdapter = adapter;
    final refresher = TokenRefresher(bareDio: dio, storage: storage);

    expect(await refresher.refresh(), isFalse);
    expect(adapter.calls, 0);
  });

  test('rafraîchit et persiste la nouvelle paire de jetons', () async {
    await storage.save(
      const StoredTokens(
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
      ),
    );
    dio.httpClientAdapter = _FakeAdapter(
      (_) async => _json(200, {
        'data': {
          'accessToken': 'new-access',
          'accessTokenExpiresIn': 900,
          'refreshToken': 'new-refresh',
          'refreshTokenExpiresAt': '2027-01-01T00:00:00.000Z',
        },
        'meta': <String, Object?>{},
        'requestId': 'test',
      }),
    );
    final refresher = TokenRefresher(bareDio: dio, storage: storage);

    expect(await refresher.refresh(), isTrue);
    expect(await storage.readAccessToken(), 'new-access');
    expect(await storage.readRefreshToken(), 'new-refresh');
  });

  test('401 : efface les jetons et signale la session expirée', () async {
    await storage.save(
      const StoredTokens(accessToken: 'old-access', refreshToken: 'reused'),
    );
    dio.httpClientAdapter = _FakeAdapter(
      (_) async => _json(401, {
        'error': {
          'code': 'UNAUTHORIZED',
          'message': 'Session expirée ou invalide.',
          'details': <Object?>[],
          'requestId': 'test',
        },
      }),
    );
    final refresher = TokenRefresher(bareDio: dio, storage: storage);
    var expired = false;
    refresher.onSessionExpired = () => expired = true;

    expect(await refresher.refresh(), isFalse);
    expect(expired, isTrue);
    expect(await storage.hasSession, isFalse);
  });

  test(
    'single-flight : des rafraîchissements simultanés ne font qu’un appel',
    () async {
      await storage.save(
        const StoredTokens(accessToken: 'old', refreshToken: 'refresh-1'),
      );
      final adapter = _FakeAdapter((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _json(200, {
          'data': {
            'accessToken': 'new-access',
            'accessTokenExpiresIn': 900,
            'refreshToken': 'new-refresh',
            'refreshTokenExpiresAt': '2027-01-01T00:00:00.000Z',
          },
          'meta': <String, Object?>{},
          'requestId': 'test',
        });
      });
      dio.httpClientAdapter = adapter;
      final refresher = TokenRefresher(bareDio: dio, storage: storage);

      final results = await Future.wait([
        refresher.refresh(),
        refresher.refresh(),
        refresher.refresh(),
      ]);

      expect(results, everyElement(isTrue));
      expect(adapter.calls, 1);
    },
  );
}
