import 'dart:convert';
import 'dart:typed_data';

import 'package:carlys_mobile/core/synchronization/sync_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptateur HTTP qui ne sort jamais sur le réseau : il note chaque requête
/// telle que Dio l'aurait émise (chemin, méthode, en-têtes) et répond 200.
class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'data': null}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// La clé d'idempotence stockée dans la file doit RÉELLEMENT partir sur le
/// fil : c'est sur l'en-tête que le serveur corrèle les rejeux dans ses
/// journaux, pas sur une colonne locale.
void main() {
  late _RecordingAdapter adapter;
  late DioSyncApi api;

  setUp(() {
    adapter = _RecordingAdapter();
    api = DioSyncApi(
      Dio(BaseOptions(baseUrl: 'http://localhost/api/v1'))
        ..httpClientAdapter = adapter,
    );
  });

  String headerOf(RequestOptions request) =>
      request.headers[idempotencyKeyHeader] as String;

  test('chaque appel porte la clé en en-tête Idempotency-Key', () async {
    await api.createSession({'id': 's-1'}, idempotencyKey: 's-1');
    await api.completeSession('s-1', {}, idempotencyKey: 's-1');
    await api.abandonSession('s-1', {}, idempotencyKey: 's-1');
    await api.upsertSet('s-1', {'id': 'set-1'}, idempotencyKey: 'set-1');
    await api.deleteSet('set-1', idempotencyKey: 'set-1');
    await api.skipPlanItems('s-1', {
      'planItemIds': <String>[],
    }, idempotencyKey: 's-1');
    await api.saveTemplate('t-1', {}, idempotencyKey: 't-1');
    await api.deleteTemplate('t-1', idempotencyKey: 't-1');

    expect(adapter.requests, hasLength(8));
    expect(adapter.requests.map(headerOf), [
      's-1',
      's-1',
      's-1',
      'set-1',
      'set-1',
      's-1',
      't-1',
      't-1',
    ]);
    // Les chemins n'ont pas bougé : l'en-tête s'ajoute, il ne remplace rien.
    expect(adapter.requests.first.path, '/workout-sessions');
    expect(adapter.requests.first.method, 'POST');
    expect(adapter.requests[4].path, '/workout-sets/set-1');
    expect(adapter.requests[4].method, 'DELETE');
  });
}
