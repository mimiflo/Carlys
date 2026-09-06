import 'dart:convert';

import '../database/app_database.dart';
import 'sync_api.dart';

/// Traduit une opération de la file en appel [SyncApi].
///
/// Chaque envoi porte la clé d'idempotence de l'opération : le serveur est
/// idempotent par UUID client, l'en-tête sert à retrouver les rejeux d'une
/// même opération dans ses journaux.
class SyncDispatcher {
  const SyncDispatcher(this._api);

  final SyncApi _api;

  /// Jette une [StateError] pour un type d'opération inconnu et une
  /// [TypeError] pour une charge utile malformée — deux `Error`, que le
  /// moteur attrape pour marquer l'opération en échec sans bloquer la file.
  Future<void> send(SyncOperation operation) async {
    final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
    final key = operation.idempotencyKey;
    switch (operation.operationType) {
      case 'session.create':
        await _api.createSession(payload, idempotencyKey: key);
      case 'session.complete':
        await _api.completeSession(
          operation.entityId,
          payload['body'] as Map<String, dynamic>,
          idempotencyKey: key,
        );
      case 'session.abandon':
        await _api.abandonSession(
          operation.entityId,
          payload['body'] as Map<String, dynamic>,
          idempotencyKey: key,
        );
      case 'set.upsert':
        await _api.upsertSet(
          payload['sessionId'] as String,
          payload['body'] as Map<String, dynamic>,
          idempotencyKey: key,
        );
      case 'set.delete':
        await _api.deleteSet(operation.entityId, idempotencyKey: key);
      case 'plan.skip':
        await _api.skipPlanItems(
          operation.entityId,
          payload['body'] as Map<String, dynamic>,
          idempotencyKey: key,
        );
      case 'template.save':
        await _api.saveTemplate(
          operation.entityId,
          payload['body'] as Map<String, dynamic>,
          idempotencyKey: key,
        );
      case 'template.delete':
        await _api.deleteTemplate(operation.entityId, idempotencyKey: key);
      default:
        throw StateError('Opération inconnue : ${operation.operationType}');
    }
  }
}

/// La **voie** d'une opération : l'entité racine dont dépend l'ordre.
///
/// Les opérations d'une même séance (création, séries, prévisions passées,
/// clôture) doivent partir dans l'ordre : une série envoyée avant la
/// création de sa séance serait refusée pour toujours. Une opération mise
/// de côté retient donc celles qui la suivent SUR SA VOIE, et seulement
/// celles-là — un modèle ou une autre séance partent sans l'attendre.
String syncLaneOf(SyncOperation operation) {
  switch (operation.entityType) {
    case 'session':
    case 'plan':
      return 'session:${operation.entityId}';
    case 'set':
      final sessionId = _sessionIdOf(operation.payload);
      // Une opération écrite avant que le corps ne porte `sessionId` fait
      // voie à part : elle ne retient rien et n'est retenue par rien.
      return sessionId == null
          ? 'set:${operation.entityId}'
          : 'session:$sessionId';
    default:
      return '${operation.entityType}:${operation.entityId}';
  }
}

String? _sessionIdOf(String payload) {
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      final sessionId = decoded['sessionId'];
      if (sessionId is String) {
        return sessionId;
      }
    }
  } on FormatException {
    // Charge illisible : le moteur la marquera en échec à l'envoi. Ici, elle
    // ne doit surtout pas faire tomber le drainage entier.
  }
  return null;
}
