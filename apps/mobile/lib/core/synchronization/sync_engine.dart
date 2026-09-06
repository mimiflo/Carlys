import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../logging/app_logger.dart';
import 'sync_api.dart';
import 'sync_dispatcher.dart';
import 'sync_entity_marker.dart';

/// Draine la file d'opérations vers l'API.
///
/// Propriétés :
///  - FIFO strict : l'ordre d'écriture local est préservé côté serveur ;
///  - single-flight : un seul drainage à la fois ;
///  - backoff exponentiel par opération après un échec réseau ou serveur,
///    plafonné à 5 minutes ;
///  - une erreur 4xx marque l'opération `failed` sans bloquer la file ;
///  - au-delà de [serverAttemptsMax] réponses 5xx d'affilée, l'opération est
///    mise de côté (`exhausted`) : elle ne retient plus que les opérations
///    de SA voie (même séance) et repart à la prochaine ouverture ;
///  - une opération réussie est supprimée (résiste à une fermeture brutale :
///    au pire elle est rejouée, le serveur est idempotent).
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required SyncApi api,
    DateTime Function()? now,
  }) : _db = database,
       _dispatcher = SyncDispatcher(api),
       _marker = SyncEntityMarker(database),
       _now = now ?? DateTime.now;

  static const _logger = AppLogger('SyncEngine');

  /// Réponses 5xx d'affilée tolérées pour UNE opération avant de la mettre
  /// de côté. Cinq, c'est une dizaine de minutes de replis avec les réveils
  /// périodiques : assez pour absorber un redémarrage du serveur, pas assez
  /// pour qu'une opération empoisonnée bloque une séance entière jusqu'au
  /// prochain redémarrage à froid. Les coupures réseau ne comptent pas :
  /// elles frappent toute la file, pas une opération.
  static const int serverAttemptsMax = 5;

  final AppDatabase _db;
  final SyncDispatcher _dispatcher;
  final SyncEntityMarker _marker;

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

  /// Redonne leur chance aux opérations mises de côté : à l'ouverture de
  /// l'application, ou sur demande. Elles repartent en tête de leur voie,
  /// compteurs à zéro, et l'entité redevient « en attente » à l'écran.
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
        await (_db.update(
          _db.syncOperations,
        )..where((op) => op.id.equals(operation.id))).write(
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

  Future<void> _drain() async {
    final operations =
        await (_db.select(_db.syncOperations)
              ..where((op) => op.status.isIn(const ['pending', 'exhausted']))
              ..orderBy([(op) => OrderingTerm.asc(op.createdAt)]))
            .get();

    // Voies retenues par une opération mise de côté : ce qui les suit sur la
    // même séance attend, tout le reste part.
    final heldLanes = <String>{};

    for (final operation in operations) {
      final lane = syncLaneOf(operation);
      if (operation.status != 'pending') {
        heldLanes.add(lane);
        continue;
      }
      if (heldLanes.contains(lane)) {
        continue;
      }
      if (!_isDue(operation)) {
        // FIFO strict : on ne double jamais une opération en attente.
        return;
      }
      try {
        await _dispatcher.send(operation);
        await _onSuccess(operation);
      } on DioException catch (exception) {
        final statusCode = exception.response?.statusCode;
        if (statusCode != null &&
            statusCode >= 400 &&
            statusCode < 500 &&
            statusCode != 401 &&
            statusCode != 429) {
          // Refus définitif du serveur : on ne bloque pas la file.
          await _onRejected(operation, 'HTTP $statusCode');
          continue;
        }
        if (statusCode != null && statusCode >= 500) {
          if (await _onServerError(operation, statusCode)) {
            heldLanes.add(lane);
            continue;
          }
          return;
        }
        // Réseau, 401 (session à renouveler) ou 429 (débit) : plus tard.
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

  Future<void> _onSuccess(SyncOperation operation) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.syncOperations,
      )..where((op) => op.id.equals(operation.id))).go();
      await _marker.mark(operation, 'synced');
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

  /// Compte la réponse 5xx ; rend `true` si l'opération vient d'être mise de
  /// côté (plafond atteint), `false` si elle attend simplement son backoff.
  Future<bool> _onServerError(SyncOperation operation, int statusCode) async {
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
      await (_db.update(
        _db.syncOperations,
      )..where((op) => op.id.equals(operation.id))).write(
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
      await _marker.mark(operation, 'failed');
    });
  }
}

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    database: ref.watch(appDatabaseProvider),
    api: ref.watch(syncApiProvider),
  );
});
