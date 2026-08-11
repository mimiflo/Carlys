import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/repositories/nutrition_repository.dart';

/// NutritionRepository de test — profil en mémoire, rapport « serveur » figé.
///
/// Reproduit le contrat : liste des champs manquants dans l'ordre serveur,
/// métabolisme calculé uniquement quand le profil est complet (valeurs de
/// référence du calculateur : homme, 30 ans, 180 cm, 80 kg, modéré).
class FakeNutritionRepository implements NutritionRepository {
  FakeNutritionRepository({
    this.weightKg,
    BiologicalSex? sex,
    DateTime? birthDate,
    double? heightCm,
    ActivityLevel? activityLevel,
    NutritionGoal? goal,
  })  : _sex = sex,
        _birthDate = birthDate,
        _heightCm = heightCm,
        _activityLevel = activityLevel,
        _goal = goal;

  double? weightKg;
  BiologicalSex? _sex;
  DateTime? _birthDate;
  double? _heightCm;
  ActivityLevel? _activityLevel;
  NutritionGoal? _goal;

  int updateCount = 0;

  static const referenceResult = MetabolismResult(
    bmi: 24.7,
    bmiCategory: BmiCategory.normal,
    bmrKcal: 1780,
    tdeeKcal: 2759,
    targetKcal: 2759,
    proteinG: 128,
    fatG: 77,
    carbsG: 389,
    waterMl: 2800,
  );

  @override
  Future<MetabolismReport> metabolismReport() async {
    final missing = <MetabolismMissingField>[
      if (_sex == null) MetabolismMissingField.sex,
      if (_birthDate == null) MetabolismMissingField.birthDate,
      if (_heightCm == null) MetabolismMissingField.heightCm,
      if (_activityLevel == null) MetabolismMissingField.activityLevel,
      if (weightKg == null) MetabolismMissingField.weightKg,
    ];

    return MetabolismReport(
      profile: MetabolicProfile(
        sex: _sex,
        birthDate: _birthDate,
        ageYears: _birthDate == null ? null : 30,
        heightCm: _heightCm,
        weightKg: weightKg,
        activityLevel: _activityLevel,
        goal: _goal,
      ),
      missing: missing,
      metabolism: missing.isEmpty ? referenceResult : null,
    );
  }

  @override
  Future<void> updateProfile(MetabolicProfileUpdate update) async {
    updateCount++;
    _sex = update.sex ?? _sex;
    _birthDate = update.birthDate ?? _birthDate;
    _heightCm = update.heightCm ?? _heightCm;
    _activityLevel = update.activityLevel ?? _activityLevel;
    _goal = update.goal ?? _goal;
  }

  /// Journal en mémoire, pilotable par les tests.
  final List<MealEntry> meals = [];

  @override
  Future<List<MealEntry>> mealsBetween(DateTime from, DateTime to) async =>
      meals
          .where(
            (meal) => !meal.eatenAt.isBefore(from) && meal.eatenAt.isBefore(to),
          )
          .toList()
        ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));

  @override
  Future<MealEntry> addMeal(MealEntry meal) async {
    if (meals.every((entry) => entry.id != meal.id)) {
      meals.add(meal);
    }
    return meal;
  }

  @override
  Future<void> deleteMeal(String id) async {
    meals.removeWhere((meal) => meal.id == id);
  }
}
