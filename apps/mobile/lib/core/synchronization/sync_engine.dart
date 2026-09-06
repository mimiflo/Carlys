import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../logging/app_logger.dart';
import 'sync_api.dart';

/// Draine la file d'opérations vers l'API.
///
/// Propriétés :
///  - FIFO strict : l'ordre d'écriture local est préservé côté serveur ;
///  - single-flight : un seul drainage à la fois ;
///  - backoff exponentiel par opération après un échec réseau ;
///  - une erreur 4xx marque l'opération `failed` sans bloquer la file ;
///  - une opération réussie est supprimée (résiste à une fermeture brutale :
///    au pire elle est rejouée, le serveur est idempotent).
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required this._api,
    DateTime Function()? now,
  }) : _db = database,
       _now = now ?? DateTime.now;

  static const _logger = AppLogger('SyncEngine');

  final AppDatabase _db;
  final SyncApi _api;

  /// Horloge injectable (déterminisme des tests de backoff).
  final DateTime Function() _now;
  Future<void>? _inFlight;
  bool _pokedDuringDrain = false;

  /// Délai d'attente avant nouvel essai : 5 s, 10 s, 20 s… plafonné à 5 min.
  ///
  /// L'exposant est BORNÉ avant `pow` : le plafond est atteint dès la 7e
  /// tentative, et `pow(2, n)` déborde en infini vers n = 1024 — soit trois
  /// jours de replis à 5 minutes, après quoi `toInt()` jetterait et tuerait
  /// la synchronisation pour de bon.
  static Duration backoff(int attemptCount) {
    final exponent = (attemptCount - 1).clamp(0, 6);
    final seconds = 5 * math.pow(2, exponent).toInt();
    return Duration(seconds: math.min(seconds, 300));
  }

  /// Draine la file. Un appel pendant un drainage en cours ne double rien —
  /// il NOTE qu'il faudra recommencer : l'opération qui vient d'être écrite
  /// n'est pas dans l'instantané que le drainage en cours a déjà lu, et sans
  /// cette note elle attendrait le prochain réveil périodique (3 minutes).
  Future<void> syncNow() {
    final running = _inFlight;
    if (running != null) {
      _pokedDuringDrain = true;
      return running;
    }
    final drain = () async {
      do {
        _pokedDuringDrain = false;
        await _drain();
      } while (_pokedDuringDrain);
    }();
    return _inFlight = drain.whenComplete(() => _inFlight = null);
  }

  Future<void> _drain() async {
    final operations =
        await (_db.select(_db.syncOperations)
              ..where((op) => op.status.equals('pending'))
              ..orderBy([(op) => OrderingTerm.asc(op.createdAt)]))
            .get();

    for (final operation in operations) {
      if (!_isDue(operation)) {
        // FIFO strict : on ne double jamais une opération en attente.
        return;
      }
      try {
        await _send(operation);
        await _onSuccess(operation);
      } on DioException catch (exception) {
        final statusCode = exception.response?.statusCode;
        if (statusCode != null &&
            statusCode >= 400 &&
            statusCode < 500 &&
            statusCode != 401) {
          // Refus définitif du serveur : on ne bloque pas la file.
          await _onRejected(operation, 'HTTP $statusCode');
          continue;
        }
        // Réseau, 401 (session à renouveler) ou 5xx : on retentera plus tard.
        await _onRetryLater(operation);
        return;
      } catch (exception) {
        // Attrape TOUT, pas seulement `Exception` : un type d'opération
        // inconnu jette une `StateError` et une charge utile malformée une
        // `TypeError` — deux `Error`, qu'un `on Exception` laisse passer.
        // Non attrapées, elles bloqueraient la tête de file pour toujours,
        // avec une erreur non gérée à chaque réveil. Aucune de ces causes ne
        // guérit en réessayant : on marque l'opération en échec et on passe.
        _logger.error(
          'Opération de sync inattendue en échec',
          error: exception,
        );
        await _onRejected(operation, exception.toString());
      }
    }
  }

  bool _isDue(SyncOperation operation) {
    final lastAttempt = operation.lastAttemptAt;
    if (lastAttempt == null) {
      return true;
    }
    return _now().isAfter(lastAttempt.add(backoff(operation.attemptCount)));
  }

  /// Chaque envoi porte la clé d'idempotence de l'opération : le serveur
  /// est idempotent par UUID client, l'en-tête sert à retrouver les rejeux
  /// d'une même opération dans ses journaux.
  Future<void> _send(SyncOperation operation) async {
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

  Future<void> _onSuccess(SyncOperation operation) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.syncOperations,
      )..where((op) => op.id.equals(operation.id))).go();
      await _markEntity(operation, 'synced');
    });
  }

  Future<void> _onRetryLater(SyncOperation operation) async {
    await (_db.update(
      _db.syncOperations,
    )..where((op) => op.id.equals(operation.id))).write(
      SyncOperationsCompanion(
        attemptCount: Value(operation.attemptCount + 1),
        lastAttemptAt: Value(_now()),
      ),
    );
  }

  Future<void> _onRejected(SyncOperation operation, String error) async {
    _logger.warning('Opération rejetée par le serveur : $error');
    await _db.transaction(() async {
      await (_db.update(
        _db.syncOperations,
      )..where((op) => op.id.equals(operation.id))).write(
        SyncOperationsCompanion(
          status: const Value('failed'),
          error: Value(error),
        ),
      );
      await _markEntity(operation, 'failed');
    });
  }

  Future<void> _markEntity(SyncOperation operation, String syncStatus) async {
    switch (operation.entityType) {
      case 'session':
        await (_db.update(
          _db.localWorkoutSessions,
        )..where((session) => session.id.equals(operation.entityId))).write(
          LocalWorkoutSessionsCompanion(syncStatus: Value(syncStatus)),
        );
      case 'set':
        await (_db.update(_db.localWorkoutSets)
              ..where((set) => set.id.equals(operation.entityId)))
            .write(LocalWorkoutSetsCompanion(syncStatus: Value(syncStatus)));
      case 'template':
        await (_db.update(
          _db.localWorkoutTemplates,
        )..where((template) => template.id.equals(operation.entityId))).write(
          LocalWorkoutTemplatesCompanion(syncStatus: Value(syncStatus)),
        );
    }
    await _markPlanItems(operation, syncStatus);
  }

  /// Le plan n'a pas d'opération à lui seul : il voyage AVEC autre chose.
  /// L'acquittement suit donc le transporteur — la création de séance pour le
  /// plan entier, la série pour son appariement, et `plan.skip` pour les
  /// prévisions passées.
  Future<void> _markPlanItems(
    SyncOperation operation,
    String syncStatus,
  ) async {
    final update = _db.update(_db.localSessionPlanItems);
    final value = LocalSessionPlanItemsCompanion(syncStatus: Value(syncStatus));

    switch (operation.operationType) {
      case 'session.create':
        await (update
              ..where((item) => item.sessionId.equals(operation.entityId)))
            .write(value);
      case 'plan.skip':
        final ids = _planItemIdsOf(operation);
        if (ids.isNotEmpty) {
          await (update..where((item) => item.id.isIn(ids))).write(value);
        }
      case 'set.upsert':
        final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
        final body = payload['body'] as Map<String, dynamic>;
        final planItemId = body['planItemId'] as String?;
        if (planItemId != null) {
          await (update..where((item) => item.id.equals(planItemId))).write(
            value,
          );
        }
    }
  }

  List<String> _planItemIdsOf(SyncOperation operation) {
    final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
    final body = payload['body'] as Map<String, dynamic>;
    return (body['planItemIds'] as List<dynamic>).cast<String>();
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    database: ref.watch(appDatabaseProvider),
    api: ref.watch(syncApiProvider),
  );
});
