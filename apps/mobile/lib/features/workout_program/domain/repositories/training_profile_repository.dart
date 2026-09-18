import '../entities/training_profile.dart';

/// Entrées de génération de programme — le serveur est la source de
/// vérité : lire rend l'état complet, écrire ne porte que ce qui change.
abstract class TrainingProfileRepository {
  Future<TrainingProfile> fetch();

  /// Écrit les champs FOURNIS, et eux seuls (`PATCH /users/me`).
  /// [equipmentSlugs] est un remplacement complet de la liste — un slug
  /// hors taxonomie est refusé par le serveur, jamais ignoré.
  Future<void> patch({
    TrainingExperience? experience,
    int? weeklySessionsTarget,
    int? sessionMinutesTarget,
    List<String>? equipmentSlugs,
  });
}
