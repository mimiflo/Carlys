import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../logging/app_logger.dart';
import 'sync_entity_marker.dart';

/// Transitions d'état d'une opération de la file, et leur reflet sur
/// l'entité locale — chacune dans une transaction, pour qu'une coupure ne
/// laisse jamais la file et l'entité en désaccord.
///
/// États : `pending` (à envoyer), `failed` (refus définitif), `exhausted`
/// (trop d'erreurs serveur, rejouée à l'ouverture suivante), `conflict`
/// (clôture refusée, décision utilisateur). Une opération réussie est
/// supprimée : l'état `synced` vit sur l'entité.
class SyncOperationStates {
  SyncOperationStates({required AppDatabase database, required this._now})
    : _db = database,
      _marker = SyncEntityMarker(database);

  static const _logger = AppLogger('SyncEngine');

  final AppDatabase _db;
  final SyncEntityMarker _marker;
  final DateTime Function() _now;

  Future<void> succeeded(SyncOperation operation) async {
    await _db.transaction(() async {
      await _delete(operation);
      await _marker.mark(operation, 'synced');
    });
  }

  Future<void> retryLater(SyncOperation operation) async {
    await _write(
      operation,
      SyncOperationsCompanion(
        attemptCount: Value(operation.attemptCount + 1),
        lastAttemptAt: Value(_now()),
      ),
    );
  }

  /// Compte la réponse 5xx ; rend `true` si l'opération vient d'être mise de
  /// côté (plafond [serverAttemptsMax] atteint), `false` si elle attend
  /// simplement son backoff.
  Future<bool> serverError(
    SyncOperation operation,
    int statusCode, {
    required int serverAttemptsMax,
  }) async {
    final serverErrors = operation.serverErrorCount + 1;
    final exhausted = serverErrors >= serverAttemptsMax;
    if (exhausted) {
      _logger.warning(
        'Opération ${operation.operationType} mise de côté après '
        '$serverErrors réponses HTTP $statusCode : elle repartira à la '
        'prochaine ouverture',
      );
    }
    await _db.transaction(() async {
      await _write(
        operation,
        SyncOperationsCompanion(
          attemptCount: Value(operation.attemptCount + 1),
          lastAttemptAt: Value(_now()),
          serverErrorCount: Value(serverErrors),
          status: Value(exhausted ? 'exhausted' : 'pending'),
          error: Value(exhausted ? 'HTTP $statusCode' : null),
        ),
      );
      if (exhausted) {
        await _marker.mark(operation, 'failed');
      }
    });
    return exhausted;
  }

  Future<void> rejected(SyncOperation operation, String error) async {
    _logger.warning('Opération rejetée par le serveur : $error');
    await _db.transaction(() async {
      await _write(
        operation,
        SyncOperationsCompanion(
          status: const Value('failed'),
          error: Value(error),
        ),
      );
      await _marker.mark(operation, 'failed');
    });
  }

  /// La clôture est refusée parce que le serveur a clôturé autrement : la
  /// séance passe en conflit à l'écran, l'opération attend la décision.
  Future<void> conflict(SyncOperation operation) async {
    _logger.info(
      'Séance ${operation.entityId} clôturée autrement sur le serveur : '
      'arbitrage demandé',
    );
    await _db.transaction(() async {
      await _write(
        operation,
        const SyncOperationsCompanion(
          status: Value('conflict'),
          error: Value('HTTP 409'),
        ),
      );
      await _marker.mark(operation, 'conflict');
    });
  }

  /// Opération écrite sous un autre compte que celui connecté : supprimée,
  /// jamais envoyée. L'entité locale, si elle existe encore, n'est pas
  /// touchée — la purge à la frontière de compte s'en charge.
  Future<void> purgeForeign(SyncOperation operation) async {
    _logger.warning(
      'Opération ${operation.operationType} ${operation.id} écrite sous un '
      'autre compte : supprimée sans envoi',
    );
    await _delete(operation);
  }

  /// Redonne leur chance aux opérations mises de côté : compteurs à zéro,
  /// et l'entité redevient « en attente » à l'écran.
  Future<void> retryExhausted() async {
    final exhausted = await (_db.select(
      _db.syncOperations,
    )..where((op) => op.status.equals('exhausted'))).get();
    if (exhausted.isEmpty) {
      return;
    }
    _logger.info('${exhausted.length} opération(s) mise(s) de côté rejouée(s)');
    await _db.transaction(() async {
      for (final operation in exhausted) {
        await _write(
          operation,
          const SyncOperationsCompanion(
            status: Value('pending'),
            error: Value(null),
            attemptCount: Value(0),
            serverErrorCount: Value(0),
            lastAttemptAt: Value(null),
          ),
        );
        await _marker.mark(operation, 'pending');
      }
    });
  }

  Future<void> _write(SyncOperation operation, SyncOperationsCompanion values) {
    return (_db.update(
      _db.syncOperations,
    )..where((op) => op.id.equals(operation.id))).write(values);
  }

  Future<void> _delete(SyncOperation operation) {
    return (_db.delete(
      _db.syncOperations,
    )..where((op) => op.id.equals(operation.id))).go();
  }
}
