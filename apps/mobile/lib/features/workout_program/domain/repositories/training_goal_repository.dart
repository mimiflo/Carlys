import '../entities/training_goal.dart';

/// Choix de l'objectif d'entraînement — le serveur est la source de vérité,
/// la lecture passe par le profil utilisateur (`AuthUser.trainingGoal`).
abstract class TrainingGoalRepository {
  /// Choisit (ou change) l'objectif. Rejouable à volonté : un objectif
  /// évolue avec la saison, ce n'est pas un engagement.
  Future<void> choose(TrainingGoal goal);
}
