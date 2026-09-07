import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workout_session/data/repositories/workout_close_conflict_resolver.dart';
import '../database/app_database.dart';
import '../logging/app_logger.dart';
import 'sync_api.dart';
import 'sync_conflict_resolver.dart';
import 'sync_dispatcher.dart';
import 'sync_operation_states.dart';
import 'sync_owner.dart';

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
///  - un 409 à la clôture d'une séance est tranché par le
///    [SyncConflictResolver] : version serveur adoptée si l'issue est la
///    même, sinon la séance passe en conflit et attend l'utilisateur ;
///  - une opération réussie est supprimée (résiste à une fermeture brutale :
///    au pire elle est rejouée, le serveur est idempotent).
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required SyncApi api,
    SyncConflictResolver? conflictResolver,
    this._owner,
    DateTime Function()? now,
  }) : _db = database,
       _dispatcher = SyncDispatcher(api),
       _conflicts = conflictResolver,
       _states = SyncOperationStates(
         database: database,
         now: now ?? DateTime.now,
       ),
       _now = now ?? DateTime.now;

  static const _logger = AppLogger('SyncEngine');

  /// Réponses 5xx d'affilée tolérées pour UNE opération avant de la mettre
  /// de côté. Cinq, c'est une dizaine de minutes de replis avec les réveils
  /// périodiques : assez pour absorber un redémarrage du serveur, pas assez
  /// pour qu'une opération empoisonnée bloque une séance entière jusqu'au
  /// prochain redémarrage à froid. Les coupures réseau ne comptent pas :
  /// elles frappent toute la file, pas une opération.
  static const int serverAttemptsMax = 5;

  static const _closingOperations = {'session.complete', 'session.abandon'};

  final AppDatabase _db;
  final SyncDispatcher _dispatcher;
  final SyncConflictResolver? _conflicts;

  /// Sans résolveur de propriétaire (tests, démonstration), la file part
  /// sous le compte connecté sans vérification.
  final SyncOwnerResolver? _owner;
  final SyncOperationStates _states;

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
  ///
  /// Un drainage est un travail de fond lancé sans attente : si la base est
  /// fermée sous lui (purge à la frontière de compte pendant qu'un envoi est
  /// en vol), il s'arrête et le journalise au lieu de remonter une erreur
  /// non interceptée. Rien n'est perdu : la base fermée est celle du compte
  /// qui part.
  Future<void> syncNow() {
    final running = _inFlight;
    if (running != null) {
      _pokedDuringDrain = true;
      return running;
    }
    final drain = () async {
      try {
        do {
          _pokedDuringDrain = false;
          await _drain();
        } while (_pokedDuringDrain);
      } on StateError catch (error) {
        _logger.warning('Drainage interrompu : base fermée', error: error);
      }
    }();
    return _inFlight = drain.whenComplete(() => _inFlight = null);
  }

  /// Redonne leur chance aux opérations mises de côté : à l'ouverture de
  /// l'application, ou sur demande. Les conflits, eux, attendent toujours
  /// la décision de l'utilisateur.
  ///
  /// Protégé comme [syncNow] : `SyncLifecycle.ensureStarted()` l'appelle sans
  /// attente, et l'interface peut reconstruire un cycle de vie sur l'ancienne
  /// base pendant une purge à la frontière de compte. La base fermée sous lui
  /// est celle du compte qui part : rien n'est perdu, on le journalise.
  Future<void> retryExhausted() async {
    try {
      await _states.retryExhausted();
    } on StateError catch (error) {
      _logger.warning(
        'Rejeu des mises de côté interrompu : base fermée',
        error: error,
      );
    }
  }

  Future<void> _drain() async {
    final operations =
        await (_db.select(_db.syncOperations)
              ..where(
                (op) =>
                    op.status.isIn(const ['pending', 'exhausted', 'conflict']),
              )
              ..orderBy([(op) => OrderingTerm.asc(op.createdAt)]))
            .get();
    if (operations.isEmpty) {
      return;
    }

    final ownerResolver = _owner;
    final owner = await ownerResolver?.currentOwnerId();
    if (ownerResolver != null && owner == null) {
      // Personne n'est connecté : rien ne peut partir, et surtout rien ne
      // doit être attribué au prochain compte. La file attend.
      return;
    }

    // Voies retenues par une opération mise de côté ou en conflit : ce qui
    // les suit sur la même séance attend, tout le reste part.
    final heldLanes = <String>{};

    for (final operation in operations) {
      final writtenBy = operation.ownerUserId;
      if (owner != null && writtenBy != null && writtenBy != owner) {
        // Écrite sous un autre compte : elle ne partira JAMAIS avec ce
        // jeton. La purge à la déconnexion aurait dû l'emporter ; ici, elle
        // est supprimée et journalisée.
        await _states.purgeForeign(operation);
        continue;
      }
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
      final outcome = await _attempt(operation);
      switch (outcome) {
        case _Outcome.proceed:
          continue;
        case _Outcome.hold:
          heldLanes.add(lane);
          continue;
        case _Outcome.stop:
          return;
      }
    }
  }

  Future<_Outcome> _attempt(SyncOperation operation) async {
    try {
      await _dispatcher.send(operation);
      await _states.succeeded(operation);
      return _Outcome.proceed;
    } on DioException catch (exception) {
      final statusCode = exception.response?.statusCode;
      if (statusCode == 409 &&
          _closingOperations.contains(operation.operationType)) {
        return _onCloseConflict(operation);
      }
      if (statusCode != null &&
          statusCode >= 400 &&
          statusCode < 500 &&
          statusCode != 401 &&
          statusCode != 429) {
        // Refus définitif du serveur : on ne bloque pas la file.
        await _states.rejected(operation, 'HTTP $statusCode');
        return _Outcome.proceed;
      }
      if (statusCode != null && statusCode >= 500) {
        final exhausted = await _states.serverError(
          operation,
          statusCode,
          serverAttemptsMax: serverAttemptsMax,
        );
        return exhausted ? _Outcome.hold : _Outcome.stop;
      }
      // Réseau, 401 (session à renouveler) ou 429 (débit) : plus tard.
      await _states.retryLater(operation);
      return _Outcome.stop;
    } catch (exception) {
      // Attrape TOUT, pas seulement `Exception` : un type d'opération
      // inconnu jette une `StateError` et une charge utile malformée une
      // `TypeError` — deux `Error`, qu'un `on Exception` laisse passer.
      // Non attrapées, elles bloqueraient la tête de file pour toujours,
      // avec une erreur non gérée à chaque réveil. Aucune de ces causes ne
      // guérit en réessayant : on marque l'opération en échec et on passe.
      _logger.error('Opération de sync inattendue en échec', error: exception);
      await _states.rejected(operation, exception.toString());
      return _Outcome.proceed;
    }
  }

  /// Sans résolveur (tests, démonstration), un 409 met directement la séance
  /// en conflit : l'utilisateur pourra encore prendre la version serveur.
  Future<_Outcome> _onCloseConflict(SyncOperation operation) async {
    final resolver = _conflicts;
    final verdict = resolver == null
        ? SyncConflictVerdict.conflict
        : await resolver.resolveClose(operation);
    switch (verdict) {
      case SyncConflictVerdict.adopted:
        await _states.succeeded(operation);
        return _Outcome.proceed;
      case SyncConflictVerdict.retryLater:
        await _states.retryLater(operation);
        return _Outcome.stop;
      case SyncConflictVerdict.rejected:
        await _states.rejected(operation, 'HTTP 409');
        return _Outcome.proceed;
      case SyncConflictVerdict.conflict:
        if (isArbitratedKeepLocal(operation)) {
          // L'utilisateur avait choisi sa version ; le serveur la refuse
          // encore. On ne repose pas la question : échec visible.
          await _states.rejected(operation, 'Le serveur a gardé sa version');
          return _Outcome.proceed;
        }
        await _states.conflict(operation);
        return _Outcome.hold;
    }
  }

  bool _isDue(SyncOperation operation) {
    final lastAttempt = operation.lastAttemptAt;
    if (lastAttempt == null) {
      return true;
    }
    return _now().isAfter(lastAttempt.add(backoff(operation.attemptCount)));
  }
}

/// Suite du drainage après une tentative : passer à l'opération suivante,
/// retenir la voie de celle-ci, ou s'arrêter là (FIFO strict).
enum _Outcome { proceed, hold, stop }

/// Le moteur vit dans `core` mais draine, de fait, la file des séances (voir
/// `SyncApi`) : c'est le seul endroit où `core` connaît la fonctionnalité,
/// pour brancher le résolveur qui sait lire et écrire une séance complète.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    database: ref.watch(appDatabaseProvider),
    api: ref.watch(syncApiProvider),
    conflictResolver: ref.watch(workoutCloseConflictResolverProvider),
    owner: ref.watch(syncOwnerResolverProvider),
  );
});
