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

  /// `POST /workout-sessions/{sessionId}/plan/skip` : le corps liste les
  /// prévisions passées, donc rejouer aboutit au même état. Les prévisions
  /// déjà honorées par une série sont ignorées côté serveur.
  Future<void> skipPlanItems(String sessionId, Map<String, dynamic> body);

  /// `PUT /workout-templates/{templateId}` : le corps décrit l'ÉTAT COMPLET du
  /// modèle, l'idempotence est donc naturelle (rejouer = même état).
  Future<void> saveTemplate(String templateId, Map<String, dynamic> body);

  /// `DELETE /workout-templates/{templateId}` : suppression logique, rejouable
  /// (supprimer deux fois répond 204).
  Future<void> deleteTemplate(String templateId);
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

  @override
  Future<void> skipPlanItems(String sessionId, Map<String, dynamic> body) =>
      _dio.post<void>('/workout-sessions/$sessionId/plan/skip', data: body);

  @override
  Future<void> saveTemplate(String templateId, Map<String, dynamic> body) =>
      _dio.put<void>('/workout-templates/$templateId', data: body);

  @override
  Future<void> deleteTemplate(String templateId) =>
      _dio.delete<void>('/workout-templates/$templateId');
}

final syncApiProvider = Provider<SyncApi>((ref) {
  return DioSyncApi(ref.watch(dioProvider));
});
