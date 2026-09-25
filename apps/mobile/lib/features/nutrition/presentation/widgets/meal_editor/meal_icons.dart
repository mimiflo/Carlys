/// Les dessins des notions du repas : le domaine les nomme, l'interface les
/// dessine. Rangés ici parce que le domaine ne connaît pas le design system.
library;

import 'package:flutter/widgets.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/nutrition.dart';

extension MealMomentIcon on MealMoment {
  IconData get icon => switch (this) {
    MealMoment.breakfast => AppIcons.mealBreakfast,
    MealMoment.lunch => AppIcons.mealLunch,
    MealMoment.dinner => AppIcons.mealDinner,
    MealMoment.snack => AppIcons.mealSnack,
  };
}

extension FoodFamilyIcon on FoodFamily {
  /// La vignette d'un aliment : la table n'a pas de photos, sa famille en
  /// tient lieu. Une famille inconnue prend l'assiette de la nutrition.
  IconData get icon => switch (this) {
    FoodFamily.dishes => AppIcons.foodDishes,
    FoodFamily.plants => AppIcons.foodPlants,
    FoodFamily.cereals => AppIcons.foodCereals,
    FoodFamily.proteins => AppIcons.foodProteins,
    FoodFamily.dairy => AppIcons.foodDairy,
    FoodFamily.drinks => AppIcons.foodDrinks,
    FoodFamily.frozen => AppIcons.foodFrozen,
    FoodFamily.sweets => AppIcons.foodSweets,
    FoodFamily.fats => AppIcons.foodFats,
    FoodFamily.pantry => AppIcons.foodPantry,
    FoodFamily.infant => AppIcons.foodInfant,
    FoodFamily.other => AppIcons.nutrition,
  };
}
