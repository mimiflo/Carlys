import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utilities/current_day.dart';
import '../../data/repositories/nutrition_repository_impl.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/repositories/nutrition_repository.dart';

/// Rapport métabolique courant (calculé côté serveur).
final metabolismReportProvider = FutureProvider.autoDispose<MetabolismReport>((
  ref,
) {
  return ref.watch(nutritionRepositoryProvider).metabolismReport();
});

/// Les repas d'UN JOUR CIVIL LOCAL, minuit à minuit.
///
/// Le paramètre est minuit local du jour demandé — c'est le client qui
/// connaît son fuseau, il envoie les bornes au serveur, qui ne découpe
/// jamais les journées à sa place.
///
/// La borne haute est le jour CIVIL suivant, jamais « +24 h » : la nuit du
/// changement d'heure dure 23 ou 25 heures, et un repas de 23 h 30 tombait
/// alors hors de l'intervalle demandé — il disparaissait du journal aussitôt
/// ajouté.
///
/// La famille existe parce que le journal se consulte en ARRIÈRE : une
/// journée oubliée se rattrape le lendemain, et il fallait pouvoir la lire
/// avant de pouvoir la corriger. L'accueil, lui, ne connaît qu'aujourd'hui —
/// [todayMealsProvider] le lui rend.
final mealsForDayProvider = FutureProvider.autoDispose
    .family<List<MealEntry>, DateTime>((ref, dayStart) {
      final dayEnd = nextMidnight(dayStart);
      return ref
          .watch(nutritionRepositoryProvider)
          .mealsBetween(dayStart.toUtc(), dayEnd.toUtc());
    });

/// Repas d'AUJOURD'HUI, au sens de la journée locale de l'appareil.
///
/// Le jour vient de [currentDayProvider], qui bascule TOUT SEUL à minuit :
/// lu ici par un `DateTime.now()`, il restait figé au lancement — l'accueil
/// l'observe en permanence, donc rien ne rendait jamais cet auto-disposé, et
/// les tuiles Calories et Protéines affichaient encore les totaux de la
/// veille à 0 h 05.
final todayMealsProvider = FutureProvider.autoDispose<List<MealEntry>>((ref) {
  return ref.watch(mealsForDayProvider(ref.watch(currentDayProvider)).future);
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
  ///
  /// `eatenAt` vient du formulaire et non de `DateTime.now()` : un repas se
  /// journalise souvent APRÈS coup — le soir pour le midi, le lendemain
  /// pour la veille — et l'heure de saisie le rangeait alors dans la
  /// mauvaise journée.
  Future<void> addMeal({
    required String name,
    required int kcal,
    required DateTime eatenAt,
    double? quantity,
    MealQuantityUnit? quantityUnit,
    int? proteinG,
    int? carbsG,
    int? fatG,
  }) async {
    await _repository.addMeal(
      MealEntry(
        id: _uuid.v4(),
        name: name,
        kcal: kcal,
        quantity: quantity,
        quantityUnit: quantityUnit,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        eatenAt: eatenAt.toUtc(),
      ),
    );
    _refreshJournal();
  }

  /// Corrige un repas SUR PLACE : il garde son identifiant et sa place.
  Future<void> updateMeal(String id, MealCorrection correction) async {
    await _repository.updateMeal(id, correction);
    _refreshJournal();
  }

  Future<void> deleteMeal(String id) async {
    await _repository.deleteMeal(id);
    _refreshJournal();
  }

  /// Toute la famille, pas seulement aujourd'hui : corriger la DATE d'un
  /// repas le déplace d'une journée à une autre, donc deux jours changent à
  /// la fois — et l'écran n'est pas censé savoir lesquels.
  void _refreshJournal() {
    _ref.invalidate(mealsForDayProvider);
  }
}
