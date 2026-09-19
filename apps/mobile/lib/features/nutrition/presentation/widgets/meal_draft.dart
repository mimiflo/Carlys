import '../../domain/entities/meal_entry.dart';

/// Ce que la feuille rend : un repas nommé, chiffré, quantifié et daté.
class MealDraft {
  const MealDraft({
    required this.name,
    required this.kcal,
    required this.eatenAt,
    this.quantity,
    this.quantityUnit,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  final String name;
  final int kcal;

  /// L'instant du repas, tel que la personne le dit — pas l'instant de la
  /// SAISIE : on journalise souvent après coup.
  final DateTime eatenAt;

  /// La quantité mangée et son unité, liées : `null` ensemble quand la case
  /// est restée vide. DESCRIPTIVE — elle ne multiplie pas [kcal].
  final double? quantity;
  final MealQuantityUnit? quantityUnit;

  /// Les trois macros, toutes facultatives et INDÉPENDANTES : on peut ne
  /// connaître que les protéines d'un plat, et `null` veut alors dire « on
  /// ne sait pas », pas « zéro ».
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
}
