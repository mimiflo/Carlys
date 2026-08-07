import '../entities/nutrition.dart';

/// Accès au rapport métabolique et au profil nutritionnel.
abstract interface class NutritionRepository {
  /// Rapport métabolique calculé côté serveur (profil + résultats).
  Future<MetabolismReport> metabolismReport();

  /// Met à jour le profil métabolique (seuls les champs fournis changent).
  Future<void> updateProfile(MetabolicProfileUpdate update);
}
