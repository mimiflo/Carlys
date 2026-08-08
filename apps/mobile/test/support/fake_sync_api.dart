import 'package:carlys_mobile/core/synchronization/sync_api.dart';
import 'package:dio/dio.dart';

/// SyncApi de test : journalise les appels dans l'ordre, peut simuler une
/// coupure réseau ou un refus serveur (4xx) ciblé.
class FakeSyncApi implements SyncApi {
  bool networkDown = false;

  /// Ids d'entités à refuser avec un statut 400 (une fois atteints).
  final Set<String> rejectedIds = {};

  /// Journal des appels réussis, dans l'ordre : `type:id`.
  final List<String> log = [];

  void _guard(String entityId) {
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
  Future<void> createSession(Map<String, dynamic> body) async {
    final id = body['id'] as String;
    _guard(id);
    log.add('session.create:$id');
    createdSessions.add(body);
  }

  @override
  Future<void> completeSession(
    String sessionId,
    Map<String, dynamic> body,
  ) async {
    _guard(sessionId);
    log.add('session.complete:$sessionId');
  }

  @override
  Future<void> abandonSession(
    String sessionId,
    Map<String, dynamic> body,
  ) async {
    _guard(sessionId);
    log.add('session.abandon:$sessionId');
  }

  @override
  Future<void> upsertSet(String sessionId, Map<String, dynamic> body) async {
    final id = body['id'] as String;
    _guard(id);
    log.add('set.upsert:$id');
    upsertedSets.add(body);
  }

  @override
  Future<void> deleteSet(String setId) async {
    _guard(setId);
    log.add('set.delete:$setId');
  }

  @override
  Future<void> skipPlanItems(
    String sessionId,
    Map<String, dynamic> body,
  ) async {
    _guard(sessionId);
    log.add('plan.skip:$sessionId');
    skippedPlanItems.addAll(
      (body['planItemIds'] as List<dynamic>).cast<String>(),
    );
  }

  @override
  Future<void> saveTemplate(
    String templateId,
    Map<String, dynamic> body,
  ) async {
    _guard(templateId);
    log.add('template.save:$templateId');
    savedTemplates.add(body);
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    _guard(templateId);
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
