import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';

/// En-tête qui transporte la clé d'idempotence de l'opération rejouée.
///
/// L'idempotence RÉELLE est portée par les UUID générés sur l'appareil (le
/// serveur reconnaît une entité déjà créée par son identifiant) ; l'en-tête
/// sert à corréler, dans les journaux du serveur, les rejeux d'une même
/// opération. Le serveur n'en tient aucun registre, et n'en a pas besoin.
const String idempotencyKeyHeader = 'Idempotency-Key';

/// Appels serveur de la synchronisation. Tous les endpoints sont
/// IDEMPOTENTS côté API : rejouer une requête ne duplique jamais la donnée.
///
/// Chaque appel reçoit la clé d'idempotence de l'opération qu'il rejoue et
/// la transmet dans [idempotencyKeyHeader].
abstract interface class SyncApi {
  Future<void> createSession(
    Map<String, dynamic> body, {
    required String idempotencyKey,
  });

  Future<void> completeSession(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  });

  Future<void> abandonSession(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  });

  Future<void> upsertSet(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  });

  Future<void> deleteSet(String setId, {required String idempotencyKey});

  /// `POST /workout-sessions/{sessionId}/plan/skip` : le corps liste les
  /// prévisions passées, donc rejouer aboutit au même état. Les prévisions
  /// déjà honorées par une série sont ignorées côté serveur.
  Future<void> skipPlanItems(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  });

  /// `PUT /workout-templates/{templateId}` : le corps décrit l'ÉTAT COMPLET du
  /// modèle, l'idempotence est donc naturelle (rejouer = même état).
  Future<void> saveTemplate(
    String templateId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  });

  /// `DELETE /workout-templates/{templateId}` : suppression logique, rejouable
  /// (supprimer deux fois répond 204).
  Future<void> deleteTemplate(
    String templateId, {
    required String idempotencyKey,
  });
}

class DioSyncApi implements SyncApi {
  DioSyncApi(this._dio);

  final Dio _dio;

  Options _options(String idempotencyKey) =>
      Options(headers: {idempotencyKeyHeader: idempotencyKey});

  @override
  Future<void> createSession(
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _dio.post<void>(
    '/workout-sessions',
    data: body,
    options: _options(idempotencyKey),
  );

  @override
  Future<void> completeSession(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _dio.post<void>(
    '/workout-sessions/$sessionId/complete',
    data: body,
    options: _options(idempotencyKey),
  );

  @override
  Future<void> abandonSession(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _dio.post<void>(
    '/workout-sessions/$sessionId/abandon',
    data: body,
    options: _options(idempotencyKey),
  );

  @override
  Future<void> upsertSet(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _dio.post<void>(
    '/workout-sessions/$sessionId/sets',
    data: body,
    options: _options(idempotencyKey),
  );

  @override
  Future<void> deleteSet(String setId, {required String idempotencyKey}) => _dio
      .delete<void>('/workout-sets/$setId', options: _options(idempotencyKey));

  @override
  Future<void> skipPlanItems(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _dio.post<void>(
    '/workout-sessions/$sessionId/plan/skip',
    data: body,
    options: _options(idempotencyKey),
  );

  @override
  Future<void> saveTemplate(
    String templateId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) => _dio.put<void>(
    '/workout-templates/$templateId',
    data: body,
    options: _options(idempotencyKey),
  );

  @override
  Future<void> deleteTemplate(
    String templateId, {
    required String idempotencyKey,
  }) => _dio.delete<void>(
    '/workout-templates/$templateId',
    options: _options(idempotencyKey),
  );
}

final syncApiProvider = Provider<SyncApi>((ref) {
  return DioSyncApi(ref.watch(dioProvider));
});
