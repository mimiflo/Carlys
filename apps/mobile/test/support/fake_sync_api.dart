import 'package:carlys_mobile/core/synchronization/sync_api.dart';
import 'package:dio/dio.dart';

/// SyncApi de test : journalise les appels dans l'ordre, peut simuler une
/// coupure réseau ou un refus serveur (4xx) ciblé.
class FakeSyncApi implements SyncApi {
  bool networkDown = false;

  /// Crochet d'attente appelé avant chaque envoi — permet à un test de tenir
  /// une opération « en vol » pendant qu'il agit à côté.
  Future<void> Function()? beforeCall;

  /// Ids d'entités à refuser avec un statut 400 (une fois atteints).
  final Set<String> rejectedIds = {};

  /// Journal des appels réussis, dans l'ordre : `type:id`.
  final List<String> log = [];

  /// Clés d'idempotence reçues, dans l'ordre des envois (réussis ou non).
  final List<String> idempotencyKeys = [];

  Future<void> _guard(String entityId, String idempotencyKey) async {
    await beforeCall?.call();
    idempotencyKeys.add(idempotencyKey);
    if (networkDown) {
      throw DioException(
        requestOptions: RequestOptions(path: '/sync'),
        type: DioExceptionType.connectionError,
      );
    }
    if (rejectedIds.contains(entityId)) {
      throw DioException(
        requestOptions: RequestOptions(path: '/sync'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/sync'),
          statusCode: 400,
        ),
      );
    }
  }

  @override
  Future<void> createSession(
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async {
    final id = body['id'] as String;
    await _guard(id, idempotencyKey);
    log.add('session.create:$id');
    createdSessions.add(body);
  }

  @override
  Future<void> completeSession(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async {
    await _guard(sessionId, idempotencyKey);
    log.add('session.complete:$sessionId');
  }

  @override
  Future<void> abandonSession(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async {
    await _guard(sessionId, idempotencyKey);
    log.add('session.abandon:$sessionId');
  }

  @override
  Future<void> upsertSet(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async {
    final id = body['id'] as String;
    await _guard(id, idempotencyKey);
    log.add('set.upsert:$id');
    upsertedSets.add(body);
  }

  @override
  Future<void> deleteSet(String setId, {required String idempotencyKey}) async {
    await _guard(setId, idempotencyKey);
    log.add('set.delete:$setId');
  }

  @override
  Future<void> skipPlanItems(
    String sessionId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async {
    await _guard(sessionId, idempotencyKey);
    log.add('plan.skip:$sessionId');
    skippedPlanItems.addAll(
      (body['planItemIds'] as List<dynamic>).cast<String>(),
    );
  }

  @override
  Future<void> saveTemplate(
    String templateId,
    Map<String, dynamic> body, {
    required String idempotencyKey,
  }) async {
    await _guard(templateId, idempotencyKey);
    log.add('template.save:$templateId');
    savedTemplates.add(body);
  }

  @override
  Future<void> deleteTemplate(
    String templateId, {
    required String idempotencyKey,
  }) async {
    await _guard(templateId, idempotencyKey);
    log.add('template.delete:$templateId');
  }

  /// Corps `PUT` reçus, dans l'ordre — pour vérifier la sérialisation.
  final List<Map<String, dynamic>> savedTemplates = [];

  /// Prévisions passées reçues par le serveur, dans l'ordre.
  final List<String> skippedPlanItems = [];

  /// Corps de séries reçus, dans l'ordre.
  final List<Map<String, dynamic>> upsertedSets = [];

  /// Corps `session.create` reçus — pour vérifier que le plan part avec.
  final List<Map<String, dynamic>> createdSessions = [];
}
