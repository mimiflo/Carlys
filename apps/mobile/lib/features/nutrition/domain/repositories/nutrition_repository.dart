import '../entities/nutrition.dart';

/// Accès au rapport métabolique, au profil nutritionnel et au journal
/// alimentaire.
abstract interface class NutritionRepository {
  /// Rapport métabolique calculé côté serveur (profil + résultats).
  Future<MetabolismReport> metabolismReport();

  /// Met à jour le profil métabolique (seuls les champs fournis changent).
  Future<void> updateProfile(MetabolicProfileUpdate update);

  /// Repas entre deux instants — le client envoie les bornes de SA journée
  /// locale, le serveur ne découpe jamais les jours à sa place.
  Future<List<MealEntry>> mealsBetween(DateTime from, DateTime to);

  /// Ajoute un repas (id client, création idempotente et rejouable).
  Future<MealEntry> addMeal(MealEntry meal);

  /// Retire un repas (suppression douce, idempotente).
  Future<void> deleteMeal(String id);
}
