import 'dart:convert';

import 'package:carlys_mobile/core/api/dio_client.dart';
import 'package:carlys_mobile/core/auth/token_refresher.dart';
import 'package:carlys_mobile/core/auth/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_secure_storage.dart';

/// Un JWT lisible (non signé) qui expire à [exp].
String jwt(DateTime exp, {String sub = 'u1'}) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final seconds = exp.millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'none'})}.${part({'sub': sub, 'iat': seconds - 900, 'exp': seconds})}.sig';
}

/// Le serveur : `/auth/refresh` rend [fresh], toute autre route répond 200
/// si le Bearer reçu est [fresh] ou [accepted], 401 sinon.
class _Server implements HttpClientAdapter {
  _Server({required this.fresh, this.accepted, this.refreshDown = false});

  final String fresh;
  final String? accepted;

  /// `/auth/refresh` répond 503 : le serveur peine.
  final bool refreshDown;
  int refreshes = 0;
  final List<String?> bearers = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/refresh')) {
      refreshes++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (refreshDown) return _json(503, {'error': 'en vrac'});
      return _json(200, {
        'data': {'accessToken': fresh, 'refreshToken': 'r-$refreshes'},
      });
    }
    final bearer = (options.headers['Authorization'] as String?)?.substring(7);
    bearers.add(bearer);
    return bearer == fresh || bearer == accepted
        ? _json(200, {'data': 'ok'})
        : _json(401, {'error': 'expiré'});
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Le jeton d'accès vit 15 min : au retour d'une pause plus longue, chaque
/// requête partait avec un jeton expiré — 401, rafraîchissement, rejeu :
/// trois allers-retours avant le premier écran. Il se renouvelle désormais
/// AVANT l'envoi.
void main() {
  late TokenStorage storage;
  late _Server server;
  late Dio dio;

  Future<void> build(String current, _Server s) async {
    storage = TokenStorage(FakeSecureStorage());
    await storage.save(StoredTokens(accessToken: current, refreshToken: 'r-0'));
    server = s;
    final bare = Dio(BaseOptions(baseUrl: 'http://api/api/v1'))
      ..httpClientAdapter = s;
    dio = Dio(BaseOptions(baseUrl: 'http://api/api/v1'))..httpClientAdapter = s;
    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        refresher: TokenRefresher(bareDio: bare, storage: storage),
        dio: dio,
      ),
    );
  }

  final now = DateTime.now();

  test(
    'jeton qui expire dans 30 s : renouvelé AVANT l’envoi, aucun 401',
    () async {
      final fresh = jwt(now.add(const Duration(minutes: 15)));
      await build(
        jwt(now.add(const Duration(seconds: 30))),
        _Server(fresh: fresh),
      );

      await dio.get<Object?>('/programs');

      expect(server.refreshes, 1);
      expect(server.bearers, [fresh]);
    },
  );

  test('jeton encore valide : aucun renouvellement', () async {
    final valid = jwt(now.add(const Duration(minutes: 10)));
    await build(valid, _Server(fresh: 'autre', accepted: valid));

    await dio.get<Object?>('/programs');

    expect(server.refreshes, 0);
    expect(server.bearers, [valid]);
  });

  test('une vague de requêtes au retour : UN seul renouvellement', () async {
    final fresh = jwt(now.add(const Duration(minutes: 15)));
    await build(
      jwt(now.subtract(const Duration(minutes: 5))),
      _Server(fresh: fresh),
    );

    await Future.wait([
      dio.get<Object?>('/a'),
      dio.get<Object?>('/b'),
      dio.get<Object?>('/c'),
    ]);

    expect(server.refreshes, 1);
    expect(server.bearers, [fresh, fresh, fresh]);
  });

  test(
    'horloge de l’appareil en avance : pas un renouvellement par requête',
    () async {
      // Même juste renouvelé, le jeton paraît expiré à cette horloge : on
      // cesse d'anticiper, le 401 du serveur reste le filet.
      final fresh = jwt(now.subtract(const Duration(hours: 2)));
      await build(
        jwt(now.subtract(const Duration(hours: 3))),
        _Server(fresh: fresh),
      );

      await dio.get<Object?>('/a');
      await dio.get<Object?>('/b');
      await dio.get<Object?>('/c');

      expect(server.refreshes, 1);
    },
  );

  test('serveur en peine : au plus UN renouvellement par requête, puis une '
      'pause', () async {
    final expire = jwt(now.subtract(const Duration(minutes: 5)));
    await build(expire, _Server(fresh: 'jamais', refreshDown: true));

    await expectLater(dio.get<Object?>('/a'), throwsA(isA<DioException>()));
    expect(server.refreshes, 1);
    // Dans la pause : la requête suivante ne relance pas d'avance — seul
    // son 401 tente sa chance, une fois.
    await expectLater(dio.get<Object?>('/b'), throwsA(isA<DioException>()));
    expect(server.refreshes, 2);
  });

  test('401 d’une requête partie avant un renouvellement voisin : rejouée, '
      'sans second renouvellement', () async {
    final valide = jwt(now.add(const Duration(minutes: 10)));
    final neuf = jwt(now.add(const Duration(minutes: 15)));
    await build(valide, _Server(fresh: neuf));
    // Le jeton a tourné entre l'envoi et le 401 (une requête voisine).
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path == '/vieille') {
            await storage.save(
              StoredTokens(accessToken: neuf, refreshToken: 'r-1'),
            );
          }
          handler.next(options);
        },
      ),
    );

    await dio.get<Object?>('/vieille');
    expect(server.refreshes, 0);
    expect(server.bearers.last, neuf);
  });

  test(
    'requête d’un AUTRE compte : jamais rejouée sous le jeton du suivant',
    () async {
      final deA = jwt(now.add(const Duration(minutes: 10)), sub: 'compte-a');
      final deB = jwt(now.add(const Duration(minutes: 10)), sub: 'compte-b');
      await build(deA, _Server(fresh: 'aucun', accepted: deB));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            // A se déconnecte, B se connecte, pendant l'envoi de A.
            await storage.save(
              StoredTokens(accessToken: deB, refreshToken: 'r-b'),
            );
            handler.next(options);
          },
        ),
      );

      await expectLater(
        dio.post<Object?>('/journal'),
        throwsA(isA<DioException>()),
      );
      expect(server.bearers, [deA]);
    },
  );

  test(
    'mot de passe refusé (401) : ni renouvellement ni second essai',
    () async {
      final valide = jwt(now.add(const Duration(minutes: 10)));
      await build(valide, _Server(fresh: 'autre'));

      await expectLater(
        dio.post<Object?>('/auth/change-password'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.delete<Object?>('/users/me'),
        throwsA(isA<DioException>()),
      );
      expect(server.refreshes, 0);
      expect(server.bearers, hasLength(2));
    },
  );
}
