import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/synchronization/sync_engine.dart';
import '../../../workout_session/data/local/workout_session_writer.dart';
import '../../../workout_template/data/datasources/session_plan_local_data_source.dart';
import '../../domain/entities/coach.dart';

/// Lance une séance depuis une proposition du coach.
///
/// Interface plutôt que classe concrète : le mode démo tourne sans base
/// locale, et doit pouvoir substituer sa propre implémentation comme il le
/// fait déjà pour les séances.
abstract interface class CoachSessionLauncher {
  /// Crée la séance et matérialise son plan ; rend l'identifiant de séance.
  ///
  /// Lève un [StateError] si une séance est déjà en cours — la règle « au plus
  /// une séance » appartient à `workout_session` et n'est pas redéfinie ici.
  Future<String> start(CoachSessionProposal proposal);
}

/// Implémentation offline-first, sur la base locale.
///
/// Rigoureusement le même chemin que le lancement d'un modèle
/// (`startFromTemplate`) : séance, plan et opération de synchronisation dans
/// **une seule** transaction locale, moteur notifié après le commit. La
/// proposition n'est pas une séance — elle le devient ici, et seulement quand
/// l'utilisateur l'a demandé.
///
/// Aucun appel réseau : accepter fonctionne hors ligne comme le reste des
/// séances. Le serveur apprend l'acceptation par une route séparée, qui
/// n'écrit aucune séance.
class DriftCoachSessionLauncher implements CoachSessionLauncher {
  DriftCoachSessionLauncher({
    required AppDatabase database,
    required SyncEngine syncEngine,
    Uuid uuid = const Uuid(),
  })  : _db = database,
        _sync = syncEngine,
        _uuid = uuid,
        _plans = SessionPlanLocalDataSource(database),
        _sessions = WorkoutSessionWriter(database: database, uuid: uuid);

  final AppDatabase _db;
  final SyncEngine _sync;
  final Uuid _uuid;
  final SessionPlanLocalDataSource _plans;
  final WorkoutSessionWriter _sessions;

  @override
  Future<String> start(CoachSessionProposal proposal) async {
    await _sessions.requireNoActiveSession();

    final sessionId = _uuid.v4();
    final startedAt = DateTime.now().toUtc();
    final plan = _flattenPlan(sessionId, proposal);

    await _db.transaction(() async {
      await _sessions.insertSession(
        id: sessionId,
        name: proposal.name,
        startedAt: startedAt,
        // Aucun `templateId` : une proposition n'est pas un modèle
        // enregistré. Le nom part quand même, il devient celui de la séance.
        plan: plan.map(_planItemBody).toList(),
      );
      await _plans.insertPlanItems(plan);
    });

    unawaited(_sync.syncNow());
    return sessionId;
  }

  List<LocalSessionPlanItemsCompanion> _flattenPlan(
    String sessionId,
    CoachSessionProposal proposal,
  ) {
    return [
      for (final set in proposal.sets)
        LocalSessionPlanItemsCompanion.insert(
          // Identifiant local : celui du serveur appartient à la proposition,
          // pas à la séance qui en naît.
          id: _uuid.v4(),
          sessionId: sessionId,
          exercisePosition: set.exercisePosition,
          exerciseId: Value(set.exerciseId),
          exerciseName: set.exerciseName,
          setPosition: set.setPosition,
          kind: Value(set.kind.apiValue),
          targetReps: Value(set.targetReps),
          targetWeightKg: Value(set.targetWeightKg),
          restSeconds: Value(set.restSeconds),
        ),
    ];
  }

  /// Corps d'une prévision dans `session.create`. L'`exerciseName` part
  /// toujours : c'est le repli qui garantit que le serveur n'a aucune raison
  /// de refuser la séance.
  Map<String, dynamic> _planItemBody(LocalSessionPlanItemsCompanion item) {
    return <String, dynamic>{
      'id': item.id.value,
      'exercisePosition': item.exercisePosition.value,
      if (item.exerciseId.value != null) 'exerciseId': item.exerciseId.value,
      'exerciseName': item.exerciseName.value,
      'setPosition': item.setPosition.value,
      'kind': item.kind.value,
      if (item.targetReps.value != null) 'targetReps': item.targetReps.value,
      if (item.targetWeightKg.value != null)
        'targetWeightKg': item.targetWeightKg.value,
      if (item.restSeconds.value != null) 'restSeconds': item.restSeconds.value,
    };
  }
}

final coachSessionLauncherProvider = Provider<CoachSessionLauncher>((ref) {
  return DriftCoachSessionLauncher(
    database: ref.watch(appDatabaseProvider),
    syncEngine: ref.watch(syncEngineProvider),
  );
});
