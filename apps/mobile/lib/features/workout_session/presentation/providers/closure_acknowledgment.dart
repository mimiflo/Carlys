import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../domain/entities/workout.dart';

/// Relit ce que le serveur compte quand il ACQUITTE une clôture.
///
/// Une séance close passe à `synced` quand le serveur l'a écrite : c'est là,
/// et pas à la clôture locale, que changent les séances de la vie entière et
/// les records recalculés. Sans cette relecture, un compte restauré (60
/// séances rapatriées, 149 au serveur) ne voyait sa 150e ni aux médailles ni
/// à la tuile « Séances » avant le démarrage suivant — `buildRewardFacts`
/// prend le plus grand des deux comptes, et 61 ne dépasse pas 149.
///
/// Rend [history] tel quel ; seule la PREMIÈRE lecture ne compte pas comme
/// un acquittement. Un rapatriement ajoute lui aussi des séances `synced` :
/// une relecture de plus à la connexion, sans conséquence.
Stream<List<WorkoutHistoryEntry>> rereadServerCountsOnClosure(
  Ref ref,
  Stream<List<WorkoutHistoryEntry>> history,
) {
  int? acquittees;
  return history.map((entries) {
    final count = entries
        .where(
          (entry) =>
              entry.session.status == WorkoutStatus.completed &&
              entry.session.syncState == LocalSyncState.synced,
        )
        .length;
    final before = acquittees;
    acquittees = count;
    if (before != null && count > before) {
      ref
        ..invalidate(lifetimeStatsProvider)
        ..invalidate(personalRecordsProvider);
    }
    return entries;
  });
}
