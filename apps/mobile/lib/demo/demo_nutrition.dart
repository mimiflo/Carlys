/// Nutrition et hydratation de la DÉMONSTRATION (flavor `demo`) — aucun
/// réseau. Les résultats métaboliques sont FIGÉS : le vrai calcul reste côté
/// serveur, hors de portée d'une démonstration hors ligne.
library;

import 'dart:async';

import '../features/nutrition/domain/entities/nutrition.dart';
import '../features/nutrition/domain/repositories/nutrition_repository.dart';
import '../features/nutrition/presentation/controllers/water_controllers.dart';

/// Hydratation de la DÉMONSTRATION : un compteur en mémoire, qui démarre à
/// mi-parcours pour que la cellule montre une jauge vivante plutôt qu'un
/// départ à zéro — c'est une vitrine, pas une journée réelle.
class DemoWaterStore implements WaterStore {
  final StreamController<int> _controller = StreamController<int>.broadcast();
  int _milliliters = 1250;

  @override
  Stream<int> watchToday() async* {
    yield _milliliters;
    yield* _controller.stream;
  }

  @override
  Future<int> addToday(int milliliters) async {
    _milliliters = (_milliliters + milliliters).clamp(0, 20000);
    _controller.add(_milliliters);
    return _milliliters;
  }
}

/// Profil complet modifiable ; résultats métaboliques figés et cohérents
/// avec le poids de démonstration (79,8 kg — le vrai calcul est serveur).
class DemoNutritionRepository implements NutritionRepository {
  BiologicalSex? _sex = BiologicalSex.male;
  DateTime? _birthDate = DateTime.utc(1997, 5, 14);
  double? _heightCm = 180;
  ActivityLevel? _activityLevel = ActivityLevel.moderate;
  NutritionGoal? _goal = NutritionGoal.gainMuscle;

  @override
  Future<MetabolismReport> metabolismReport() async {
    final missing = <MetabolismMissingField>[
      if (_sex == null) MetabolismMissingField.sex,
      if (_birthDate == null) MetabolismMissingField.birthDate,
      if (_heightCm == null) MetabolismMissingField.heightCm,
      if (_activityLevel == null) MetabolismMissingField.activityLevel,
    ];
    return MetabolismReport(
      profile: MetabolicProfile(
        sex: _sex,
        birthDate: _birthDate,
        ageYears: _birthDate == null ? null : 29,
        heightCm: _heightCm,
        weightKg: 79.8,
        activityLevel: _activityLevel,
        goal: _goal,
      ),
      missing: missing,
      metabolism: missing.isNotEmpty
          ? null
          : const MetabolismResult(
              bmi: 24.6,
              bmiCategory: BmiCategory.normal,
              bmrKcal: 1783,
              tdeeKcal: 2764,
              targetKcal: 3040,
              proteinG: 144,
              fatG: 84,
              carbsG: 427,
              waterMl: 2793,
            ),
    );
  }

  @override
  Future<void> updateProfile(MetabolicProfileUpdate update) async {
    _sex = update.sex ?? _sex;
    _birthDate = update.birthDate ?? _birthDate;
    _heightCm = update.heightCm ?? _heightCm;
    _activityLevel = update.activityLevel ?? _activityLevel;
    _goal = update.goal ?? _goal;
  }

  // Journal du jour : deux repas déjà saisis, pour que « consommé /
  // objectif » vive dès l'ouverture de la démo.
  final List<MealEntry> _meals = [
    MealEntry(
      id: 'demo-meal-1',
      name: 'Skyr, granola, myrtilles',
      kcal: 380,
      proteinG: 28,
      eatenAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    MealEntry(
      id: 'demo-meal-2',
      name: 'Poulet, riz, brocoli',
      kcal: 640,
      proteinG: 46,
      eatenAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  @override
  Future<List<MealEntry>> mealsBetween(DateTime from, DateTime to) async {
    return _meals
        .where(
          (meal) => !meal.eatenAt.isBefore(from) && meal.eatenAt.isBefore(to),
        )
        .toList()
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
  }

  @override
  Future<MealEntry> addMeal(MealEntry meal) async {
    // Idempotent, comme le serveur : rejouer le même id ne double rien.
    if (_meals.every((entry) => entry.id != meal.id)) {
      _meals.add(meal);
    }
    return meal;
  }

  @override
  Future<void> deleteMeal(String id) async {
    _meals.removeWhere((meal) => meal.id == id);
  }
}
