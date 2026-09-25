import 'dart:convert';
import 'dart:typed_data';

import 'package:carlys_mobile/core/api/dio_client.dart';
import 'package:carlys_mobile/core/auth/token_refresher.dart';
import 'package:carlys_mobile/core/auth/token_storage.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_secure_storage.dart';

/// LE CONTRAT HTTP DE LA PHOTO D'UN REPAS, figé sans serveur.
///
/// `PUT …/photo` : du multipart, UN fichier dans le champ « file », déclaré
/// `image/jpeg`, et RIEN d'autre (le serveur refuse tout champ texte à
/// côté). `GET …/photo` : les octets eux-mêmes, sans enveloppe ; 404 veut
/// dire « pas de photo ». `DELETE …/photo` : 204.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = [];

  /// Le corps tel qu'il est parti sur le fil, requête par requête.
  final List<Uint8List> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final wire = BytesBuilder();
    if (requestStream != null) {
      await requestStream.forEach(wire.add);
    }
    bodies.add(wire.takeBytes());
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, Object?> _mealRow({String? photoAt}) => {
  'id': 'repas-1',
  'name': 'Poulet, riz, brocoli',
  'moment': 'LUNCH',
  'kcal': 390,
  'eatenAt': '2026-09-25T10:30:00.000Z',
  'components': const <Object>[],
  'computed': false,
  'photo': photoAt == null ? null : {'updatedAt': photoAt},
};

/// Un « JPEG » reconnaissable : la signature, puis des octets qui ne
/// peuvent pas passer pour du texte.
final Uint8List _jpeg = Uint8List.fromList([
  0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, //
  for (var i = 0; i < 64; i++) (i * 37) % 256,
  0xFF, 0xD9,
]);

/// [needle] figure-t-il, tel quel, dans [haystack] ?
bool _contains(List<int> haystack, List<int> needle) {
  for (var start = 0; start + needle.length <= haystack.length; start++) {
    var match = true;
    for (var i = 0; i < needle.length; i++) {
      if (haystack[start + i] != needle[i]) {
        match = false;
        break;
      }
    }
    if (match) {
      return true;
    }
  }
  return false;
}

void main() {
  late Dio dio;
  late NutritionRepositoryImpl repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'));
    repository = NutritionRepositoryImpl(dio);
  });

  _RecordingAdapter record(ResponseBody Function(RequestOptions) respond) {
    final adapter = _RecordingAdapter(respond);
    dio.httpClientAdapter = adapter;
    return adapter;
  }

  group('PUT …/photo', () {
    test('multipart EXACT : un seul fichier « file », image/jpeg, octets '
        'intacts, aucun champ texte', () async {
      final adapter = record(
        (_) => _json(200, {
          'data': _mealRow(photoAt: '2026-09-25T10:41:00.000Z'),
          'meta': const <String, Object?>{},
          'requestId': 'test',
        }),
      );

      final meal = await repository.replaceMealPhoto('repas-1', _jpeg);

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/nutrition/meals/repas-1/photo');
      final form = request.data as FormData;
      expect(form.fields, isEmpty, reason: 'le serveur refuse tout champ');
      expect(form.files, hasLength(1));
      final file = form.files.single;
      expect(file.key, 'file');
      expect(file.value.filename, 'photo.jpg');
      expect(file.value.contentType.toString(), 'image/jpeg');
      expect(file.value.length, _jpeg.length);

      // Et sur le fil : l'en-tête multipart, la partie, les octets.
      final contentType = request.headers[Headers.contentTypeHeader] as String;
      expect(contentType, startsWith('multipart/form-data; boundary='));
      final wire = adapter.bodies.single;
      final text = latin1.decode(wire);
      expect(
        text,
        contains(
          'content-disposition: form-data; name="file"; '
          'filename="photo.jpg"',
        ),
      );
      expect(text, contains('content-type: image/jpeg'));
      expect(
        _contains(wire, _jpeg),
        isTrue,
        reason: 'octets recopiés tels quels',
      );
      expect(
        RegExp(
          'content-disposition',
          caseSensitive: false,
        ).allMatches(text).length,
        1,
        reason: 'une seule partie',
      );

      // Le repas rendu porte la NOUVELLE date : la clé de cache change.
      expect(meal.photoUpdatedAt, DateTime.utc(2026, 9, 25, 10, 41));
    });

    test('un refus du serveur (415) remonte, il ne se tait pas', () async {
      record(
        (_) => _json(415, {
          'error': {
            'code': 'UNSUPPORTED_MEDIA_TYPE',
            'message': 'Seul le JPEG est accepté.',
            'details': const <Object>[],
            'requestId': 'test',
          },
        }),
      );

      expect(
        () => repository.replaceMealPhoto('repas-1', _jpeg),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statut', 415),
        ),
      );
    });
  });

  group('GET …/photo', () {
    test('les octets eux-mêmes, sans enveloppe', () async {
      final adapter = record(
        (_) => ResponseBody.fromBytes(
          _jpeg,
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg'],
          },
        ),
      );

      final bytes = await repository.mealPhoto('repas-1');

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/nutrition/meals/repas-1/photo');
      expect(request.responseType, ResponseType.bytes);
      expect(bytes, _jpeg);
    });

    test('404 : pas de photo — un repli, pas une panne', () async {
      record(
        (_) => ResponseBody.fromString(
          '{"error":{"code":"NOT_FOUND","message":"Repas inconnu"}}',
          404,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      expect(await repository.mealPhoto('repas-1'), isNull);
    });

    test('une panne (500) remonte : l’écran retombe sur le dessin', () async {
      record((_) => ResponseBody.fromString('', 500));

      expect(
        () => repository.mealPhoto('repas-1'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  test('DELETE …/photo : 204, rien à lire', () async {
    final adapter = record((_) => ResponseBody.fromString('', 204));

    await repository.removeMealPhoto('repas-1');

    final request = adapter.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/nutrition/meals/repas-1/photo');
  });

  test('après un 401, la session renouvelée REJOUE la photo entière', () async {
    // Le rejeu de l'intercepteur : un `FormData` est un flux, lu une fois
    // par le premier envoi. Sans clone, Dio refusait de le relire, et la
    // photo échouait à chaque expiration du jeton d'accès.
    final storage = TokenStorage(FakeSecureStorage());
    await storage.save(
      const StoredTokens(accessToken: 'expire', refreshToken: 'refresh'),
    );
    final bare = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
      ..httpClientAdapter = _RecordingAdapter(
        (_) => _json(200, {
          'data': {
            'accessToken': 'neuf',
            'accessTokenExpiresIn': 900,
            'refreshToken': 'refresh-2',
            'refreshTokenExpiresAt': '2027-01-01T00:00:00.000Z',
          },
          'meta': const <String, Object?>{},
          'requestId': 'test',
        }),
      );
    var calls = 0;
    final adapter = record((options) {
      calls++;
      if (calls == 1) {
        return _json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'Jeton expiré'},
        });
      }
      return _json(200, {
        'data': _mealRow(photoAt: '2026-09-25T10:42:00.000Z'),
        'meta': const <String, Object?>{},
        'requestId': 'test',
      });
    });
    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        refresher: TokenRefresher(bareDio: bare, storage: storage),
        dio: dio,
      ),
    );

    final meal = await repository.replaceMealPhoto('repas-1', _jpeg);

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.headers['Authorization'], 'Bearer neuf');
    for (final wire in adapter.bodies) {
      expect(_contains(wire, _jpeg), isTrue);
    }
    expect(meal.photoUpdatedAt, DateTime.utc(2026, 9, 25, 10, 42));
  });
}
