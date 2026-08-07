import '../entities/workout.dart';

/// Contrat du domaine séance.
///
/// Toutes les écritures vont D'ABORD dans la base locale (jamais de perte),
/// puis sont poussées vers le serveur via la file de synchronisation.
abstract interface class WorkoutRepository {
  /// La séance en cours (au plus une), avec ses séries, en temps réel.
  Stream<WorkoutWithSets?> watchActiveWorkout();

  /// Historique local (séances terminées ou abandonnées), plus récentes d'abord.
  Stream<List<WorkoutHistoryEntry>> watchHistory();

  Future<WorkoutWithSets?> workoutDetail(String sessionId);

  /// Démarre une séance ; échoue si une séance est déjà en cours.
  Future<String> startWorkout({String? name});

  Future<void> addSet(AddSetInput input);

  Future<void> deleteSet(String setId);

  Future<void> completeWorkout(String sessionId);

  Future<void> abandonWorkout(String sessionId);
}
