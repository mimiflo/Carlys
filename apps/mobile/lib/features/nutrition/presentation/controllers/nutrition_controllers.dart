import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utilities/current_day.dart';
import '../../data/repositories/meal_photo_cache.dart';
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

  NutritionRepository get _repository => _ref.read(nutritionRepositoryProvider);

  Future<void> saveProfile(MetabolicProfileUpdate update) async {
    await _repository.updateProfile(update);
    _ref.invalidate(metabolismReportProvider);
  }

  /// Ajoute un repas sous [id], né sur l'appareil À L'OUVERTURE de l'écran
  /// de saisie : un enregistrement qui échoue puis se rejoue garde le même
  /// identifiant, et le serveur ne fait pas de doublon.
  ///
  /// `eatenAt` vient de l'écran et non de `DateTime.now()` : un repas se
  /// journalise souvent APRÈS coup — le soir pour le midi, le lendemain pour
  /// la veille — et l'heure de saisie le rangeait alors dans la mauvaise
  /// journée.
  ///
  /// [mayExist] : un essai précédent a échoué SANS qu'on sache s'il a écrit
  /// (la réponse s'est perdue : délai dépassé, coupure). Un nouveau POST
  /// rendrait alors le repas DÉJÀ écrit, sans rien réécrire, et ce qui a été
  /// corrigé entre-temps se perdrait en silence. Le repas est donc RELU
  /// d'abord : absent, il se crée ; présent, il se corrige avec tout ce que
  /// l'écran montre.
  Future<MealEntry> addMeal(
    String id,
    MealWrite write, {
    bool mayExist = false,
  }) async {
    final added = mayExist && await _exists(id)
        ? await _repository.updateMeal(id, write.overwriting())
        : await _repository.addMeal(id, write);
    _refreshJournal();
    return added;
  }

  /// Le serveur a-t-il le repas [id] ? Tout autre échec que « introuvable »
  /// remonte : on ne sait toujours pas, et rien ne doit partir.
  Future<bool> _exists(String id) async {
    try {
      await _repository.meal(id);
      return true;
    } on ServerException catch (error) {
      if (error.statusCode == 404) {
        return false;
      }
      rethrow;
    }
  }

  /// Corrige un repas SUR PLACE : il garde son identifiant et sa place.
  Future<MealEntry> updateMeal(String id, MealWrite write) async {
    final updated = await _repository.updateMeal(id, write);
    _refreshJournal();
    return updated;
  }

  Future<void> deleteMeal(String id) async {
    await _repository.deleteMeal(id);
    _ref.read(mealPhotoCacheProvider).forget(id);
    _refreshJournal();
  }

  /// Applique à un repas DÉJÀ ÉCRIT le changement de photo décidé à
  /// l'écran : la pose (`PUT`), ou la retire (`DELETE`).
  ///
  /// La photo envoyée est rangée dans le cache sous la date que le serveur
  /// lui donne : rouvrir le repas ne retélécharge pas ce qu'on vient
  /// d'envoyer.
  Future<void> applyMealPhoto(String mealId, MealPhotoChange change) async {
    final cache = _ref.read(mealPhotoCacheProvider);
    switch (change) {
      case KeepMealPhoto():
        return;
      case NewMealPhoto(:final jpeg):
        final meal = await _repository.replaceMealPhoto(mealId, jpeg);
        final updatedAt = meal.photoUpdatedAt;
        if (updatedAt != null) {
          cache.remember(mealId, updatedAt, jpeg);
        }
      case RemoveMealPhoto():
        await _repository.removeMealPhoto(mealId);
        cache.forget(mealId);
    }
    _refreshJournal();
  }

  /// Toute la famille, pas seulement aujourd'hui : corriger la DATE d'un
  /// repas le déplace d'une journée à une autre, donc deux jours changent à
  /// la fois — et l'écran n'est pas censé savoir lesquels.
  void _refreshJournal() {
    _ref.invalidate(mealsForDayProvider);
  }
}
