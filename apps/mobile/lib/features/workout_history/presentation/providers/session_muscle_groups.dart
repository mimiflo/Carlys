import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../exercises/data/repositories/exercises_repository_impl.dart';
import '../../../workout_session/domain/entities/workout.dart';

const _logger = AppLogger('SessionMuscleGroups');

/// La clé de [sessionMuscleGroupsProvider] : les exercices du catalogue
/// d'une séance, sans doublon, dans leur ordre, joints par des virgules.
///
/// Une chaîne et non la séance : relire le bilan (effort choisi, série
/// corrigée) ne doit pas redemander les fiches au serveur tant que la liste
/// des exercices n'a pas bougé.
String sessionExerciseIdsKey(List<WorkoutSetEntry> sets) => {
  for (final set in sets)
    if (set.exerciseId != null) set.exerciseId!,
}.join(',');

/// Les groupes musculaires PRINCIPAUX travaillés pendant une séance, dans
/// l'ordre de ses exercices — lus sur la fiche du catalogue
/// (`ExerciseDetail.muscles`), le lien exercice ↔ muscles que le dépôt tient
/// déjà.
///
/// Une fiche illisible (hors ligne, exercice retiré) n'apporte rien et ne
/// fait pas échouer les autres : le repos conseillé se dit alors sans
/// muscles, jamais en erreur. Un exercice libre n'a pas de fiche.
final sessionMuscleGroupsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, exerciseIdsKey) async {
      if (exerciseIdsKey.isEmpty) {
        return const []; // que des exercices libres : aucune fiche à lire
      }
      final repository = ref.watch(exercisesRepositoryProvider);
      Future<List<String>> primaryOf(String exerciseId) async {
        try {
          final detail = await repository.byIdOrSlug(exerciseId);
          return [
            for (final link in detail.muscles)
              if (link.isPrimary) link.muscleGroup.name,
          ];
        } on AppException catch (error) {
          _logger.warning('Fiche $exerciseId illisible', error: error);
          return const [];
        }
      }

      final groups = await Future.wait(
        exerciseIdsKey.split(',').map(primaryOf),
      );
      return [for (final list in groups) ...list];
    });
