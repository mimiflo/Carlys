import '../entities/meal_entry.dart';

/// Ce qui a été mangé dans la journée, en calories et en macros.
typedef DayIntake = ({int kcal, int proteinG, int carbsG, int fatG});

/// La somme des repas du jour. Une macro INCONNUE d'un repas (le serveur
/// distingue l'absence du zéro) n'y ajoute rien : le total dit ce que l'on
/// sait, jamais une valeur inventée.
DayIntake dayIntake(Iterable<MealEntry> meals) {
  var kcal = 0, protein = 0, carbs = 0, fat = 0;
  for (final meal in meals) {
    kcal += meal.kcal;
    protein += meal.proteinG ?? 0;
    carbs += meal.carbsG ?? 0;
    fat += meal.fatG ?? 0;
  }
  return (kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat);
}
