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
  ///
  /// [templateId] / [templateName] tracent la provenance quand la séance est
  /// lancée depuis un modèle. Le serveur ne refuse **jamais** une séance à
  /// cause d'un modèle inconnu : il ignore alors l'identifiant et conserve le
  /// nom transmis par le client.
  Future<String> startWorkout({
    String? name,
    String? templateId,
    String? templateName,
  });

  /// Enregistre une série réalisée et renvoie son identifiant (UUID appareil).
  ///
  /// L'identifiant est nécessaire pour rattacher la série à l'item de plan
  /// qu'elle honore (cf. `workout_template`).
  Future<String> addSet(AddSetInput input);

  Future<void> deleteSet(String setId);

  Future<void> completeWorkout(String sessionId);

  Future<void> abandonWorkout(String sessionId);

  /// Rapatrie les séances du serveur dans la base locale, avec leurs séries
  /// **et leur plan**.
  ///
  /// Utile après une réinstallation ou un changement d'appareil : c'est ce qui
  /// permet de reprendre sur un second téléphone une séance commencée sur un
  /// premier, cibles comprises. Ne touche jamais une séance dont des
  /// modifications locales n'ont pas encore été acquittées : l'appareil ne
  /// perd jamais sa propre saisie.
  Future<void> restoreSessions();
}
