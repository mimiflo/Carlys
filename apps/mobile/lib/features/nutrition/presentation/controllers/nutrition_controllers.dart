import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/nutrition_repository_impl.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/repositories/nutrition_repository.dart';

/// Rapport métabolique courant (calculé côté serveur).
final metabolismReportProvider =
    FutureProvider.autoDispose<MetabolismReport>((ref) {
  return ref.watch(nutritionRepositoryProvider).metabolismReport();
});

/// Repas d'AUJOURD'HUI, au sens de la journée locale de l'appareil : c'est
/// le client qui connaît son fuseau, il envoie les bornes au serveur.
final todayMealsProvider = FutureProvider.autoDispose<List<MealEntry>>((ref) {
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return ref
      .watch(nutritionRepositoryProvider)
      .mealsBetween(dayStart.toUtc(), dayEnd.toUtc());
});

/// Calories consommées aujourd'hui — la moitié RÉELLE du « 654 / 2 100 » de
/// l'accueil. `null` tant que le journal n'est pas chargé (ou indisponible) :
/// l'accueil retombe alors sur l'objectif seul, jamais sur un zéro inventé.
final consumedKcalTodayProvider = Provider.autoDispose<int?>((ref) {
  final meals = ref.watch(todayMealsProvider).valueOrNull;
  if (meals == null) {
    return null;
  }
  return meals.fold(0, (sum, meal) => sum! + meal.kcal);
});

/// Protéines consommées aujourd'hui, d'après le journal.
///
/// Toutes les entrées n'en portent pas : celles qui n'en déclarent pas
/// comptent zéro. Le total est donc un PLANCHER, jamais une estimation — et
/// il vaut mieux sous-compter que gonfler un chiffre que personne n'a saisi.
final consumedProteinTodayProvider = Provider.autoDispose<int?>((ref) {
  final meals = ref.watch(todayMealsProvider).valueOrNull;
  if (meals == null) {
    return null;
  }
  return meals.fold(0, (sum, meal) => sum! + (meal.proteinG ?? 0));
});

/// Actions nutrition : chaque écriture invalide les lectures concernées.
///
/// PAS d'autoDispose : l'objet est lu au build puis rappelé dans des
/// callbacks bien plus tard — la durée de vie du `Ref` capturé doit être
/// garantie, pas fortuite (même règle que les actions de la communauté).
final nutritionActionsProvider = Provider<NutritionActions>((ref) {
  return NutritionActions(ref);
});

class NutritionActions {
  NutritionActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  NutritionRepository get _repository => _ref.read(nutritionRepositoryProvider);

  Future<void> saveProfile(MetabolicProfileUpdate update) async {
    await _repository.updateProfile(update);
    _ref.invalidate(metabolismReportProvider);
  }

  /// L'identifiant naît ICI, sur l'appareil : l'écriture est rejouable.
  Future<void> addMeal({
    required String name,
    required int kcal,
    int? proteinG,
  }) async {
    await _repository.addMeal(
      MealEntry(
        id: _uuid.v4(),
        name: name,
        kcal: kcal,
        proteinG: proteinG,
        eatenAt: DateTime.now().toUtc(),
      ),
    );
    _ref.invalidate(todayMealsProvider);
  }

  Future<void> deleteMeal(String id) async {
    await _repository.deleteMeal(id);
    _ref.invalidate(todayMealsProvider);
  }
}
