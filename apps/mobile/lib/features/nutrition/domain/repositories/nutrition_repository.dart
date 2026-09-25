import 'dart:typed_data';

import '../entities/nutrition.dart';

/// Un repas lu seul, et la mention de la base d'aliments à afficher près
/// de ses valeurs quand il en porte (`null` pour un repas saisi à la main).
typedef MealDetail = ({MealEntry meal, FoodAttribution? attribution});

/// Accès au rapport métabolique, au profil nutritionnel, au journal
/// alimentaire et à la base d'aliments.
abstract interface class NutritionRepository {
  /// Rapport métabolique calculé côté serveur (profil + résultats).
  Future<MetabolismReport> metabolismReport();

  /// Met à jour le profil métabolique (seuls les champs fournis changent).
  Future<void> updateProfile(MetabolicProfileUpdate update);

  /// Repas entre deux instants — le client envoie les bornes de SA journée
  /// locale, le serveur ne découpe jamais les jours à sa place.
  Future<List<MealEntry>> mealsBetween(DateTime from, DateTime to);

  /// UN repas, aliments compris (`GET /nutrition/meals/:id`). Inconnu,
  /// supprimé ou d'autrui : le même « introuvable » (404).
  Future<MealDetail> meal(String id);

  /// Ajoute un repas sous [id], un UUID né sur l'appareil : la création est
  /// idempotente, et un envoi rejoué ne fait pas de doublon.
  Future<MealEntry> addMeal(String id, MealWrite write);

  /// Corrige un repas déjà journalisé, SUR PLACE.
  ///
  /// Supprimer puis recréer ferait disparaître le repas du total, puis
  /// revenir sous un AUTRE identifiant.
  Future<MealEntry> updateMeal(String id, MealWrite write);

  /// Retire un repas (suppression douce, idempotente).
  Future<void> deleteMeal(String id);

  /// Cherche dans la base d'aliments (`GET /nutrition/foods?q=&limit=`) :
  /// chaque mot de [query] doit figurer dans le nom. La mention de source
  /// vient avec, à afficher là où l'on cherche ; sa version est `null` tant
  /// que la base n'est pas chargée.
  Future<FoodSearchResult> searchFoods(String query, {int limit = 20});

  /// La fiche d'un aliment (404 s'il est inconnu ou retiré).
  Future<FoodDetail> food(int code);

  /// Les octets JPEG de la photo d'un repas (`GET …/meals/:id/photo`),
  /// lus avec la session de la personne : la photo est PRIVÉE. `null` quand
  /// le repas n'en a pas (le serveur répond 404, sans dire pourquoi).
  Future<Uint8List?> mealPhoto(String id);

  /// Pose ou remplace la photo (`PUT …/photo`, multipart, champ « file »,
  /// `image/jpeg`). [jpeg] est DÉJÀ préparé sur l'appareil. Rend le repas,
  /// `photoUpdatedAt` renouvelé : c'est la nouvelle clé de cache.
  Future<MealEntry> replaceMealPhoto(String id, Uint8List jpeg);

  /// Retire la photo (`DELETE …/photo`, idempotent).
  Future<void> removeMealPhoto(String id);
}
