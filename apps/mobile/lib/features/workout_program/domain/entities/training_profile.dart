import 'training_goal.dart';

/// Expérience d'entraînement — entrée de génération : elle règle le volume
/// et la complexité du programme. C'est un NIVEAU assumé, contrairement au
/// profil Carlys qui est une identité et n'en est pas un.
enum TrainingExperience {
  beginner(
    'BEGINNER',
    'Débutant',
    'Moins d’un an de pratique régulière : on pose les bases.',
  ),
  intermediate(
    'INTERMEDIATE',
    'Intermédiaire',
    'Un à trois ans : les mouvements sont acquis, le volume monte.',
  ),
  advanced(
    'ADVANCED',
    'Avancé',
    'Plus de trois ans : programmation fine et intensité pilotée.',
  );

  const TrainingExperience(this.wire, this.label, this.description);

  /// Valeur échangée avec l'API.
  final String wire;

  final String label;
  final String description;

  /// Null pour une valeur absente OU inconnue — jamais un niveau deviné.
  static TrainingExperience? fromWire(String? wire) {
    for (final experience in values) {
      if (experience.wire == wire) {
        return experience;
      }
    }
    return null;
  }
}

/// Les ENTRÉES DE GÉNÉRATION de programme, telles que le serveur les sert
/// (`GET /users/me/training`) : tout est nul ou vide tant que rien n'est
/// choisi — la génération listera ce qui manque, elle n'inventera rien.
class TrainingProfile {
  const TrainingProfile({
    required this.goal,
    required this.experience,
    required this.weeklySessionsTarget,
    required this.sessionMinutesTarget,
    required this.equipmentSlugs,
  });

  final TrainingGoal? goal;
  final TrainingExperience? experience;

  /// Séances visées par semaine (bornes du contrat : 1 à 7).
  final int? weeklySessionsTarget;

  /// Durée visée d'une séance, en minutes (bornes du contrat : 15 à 240).
  final int? sessionMinutesTarget;

  /// Slugs de la taxonomie du catalogue, triés par nom d'équipement.
  final List<String> equipmentSlugs;
}
