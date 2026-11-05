import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../exercises/presentation/providers/exercise_catalog_providers.dart';
import '../../../workout_session/domain/entities/workout.dart';

const _logger = AppLogger('SessionMuscleGroups');

/// La clé de [sessionMuscleGroupsProvider] : les exercices du catalogue
/// d'une séance, sans doublon, dans leur ordre, joints par des virgules.
///
/// Une chaîne et non la séance : relire le bilan (effort choisi, série
/// corrigée) ne doit pas redemander les fiches tant que la liste des
/// exercices n'a pas bougé.
String sessionExerciseIdsKey(List<WorkoutSetEntry> sets) => {
  for (final set in sets)
    if (set.exerciseId != null) set.exerciseId!,
}.join(',');

/// Les groupes musculaires PRINCIPAUX travaillés pendant une séance, dans
/// l'ordre de ses exercices — lus sur les fiches du catalogue
/// ([exerciseDetailProvider], celles de l'écran « Fiche exercice »), le lien
/// exercice ↔ muscles que le dépôt tient déjà.
///
/// TOUT OU RIEN : une seule fiche illisible (hors ligne, exercice retiré)
/// et la liste est vide, l'échec journalisé. Une liste partielle dirait
/// « pour pectoraux » d'une séance qui a aussi travaillé les triceps : le
/// repos conseillé se dit alors sans muscles, jamais en erreur. Un exercice
/// libre n'a pas de fiche.
final sessionMuscleGroupsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, exerciseIdsKey) async {
      if (exerciseIdsKey.isEmpty) {
        return const []; // que des exercices libres : aucune fiche à lire
      }
      try {
        final details = await Future.wait([
          for (final id in exerciseIdsKey.split(','))
            ref.watch(exerciseDetailProvider(id).future),
        ]);
        return [
          for (final detail in details)
            for (final link in detail.muscles)
              if (link.isPrimary) link.muscleGroup.name,
        ];
      } catch (error) {
        _logger.warning(
          'Fiches illisibles, repos conseillé sans muscles',
          error: error,
        );
        return const [];
      }
    });
