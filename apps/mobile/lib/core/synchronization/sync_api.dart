import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';

/// Appels serveur de la synchronisation. Tous les endpoints sont
/// IDEMPOTENTS côté API : rejouer une requête ne duplique jamais la donnée.
abstract interface class SyncApi {
  Future<void> createSession(Map<String, dynamic> body);
  Future<void> completeSession(String sessionId, Map<String, dynamic> body);
  Future<void> abandonSession(String sessionId, Map<String, dynamic> body);
  Future<void> upsertSet(String sessionId, Map<String, dynamic> body);
  Future<void> deleteSet(String setId);
}

class DioSyncApi implements SyncApi {
  DioSyncApi(this._dio);

  final Dio _dio;

  @override
  Future<void> createSession(Map<String, dynamic> body) =>
      _dio.post<void>('/workout-sessions', data: body);

  @override
  Future<void> completeSession(String sessionId, Map<String, dynamic> body) =>
      _dio.post<void>('/workout-sessions/$sessionId/complete', data: body);

  @override
  Future<void> abandonSession(String sessionId, Map<String, dynamic> body) =>
      _dio.post<void>('/workout-sessions/$sessionId/abandon', data: body);

  @override
  Future<void> upsertSet(String sessionId, Map<String, dynamic> body) =>
      _dio.post<void>('/workout-sessions/$sessionId/sets', data: body);

  @override
  Future<void> deleteSet(String setId) =>
      _dio.delete<void>('/workout-sets/$setId');
}

final syncApiProvider = Provider<SyncApi>((ref) {
  return DioSyncApi(ref.watch(dioProvider));
});
