import 'dart:async';
import 'dart:typed_data';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/repositories/nutrition_repository.dart';
import 'package:carlys_mobile/features/nutrition/domain/services/meal_composition.dart';

/// NutritionRepository de test — profil en mémoire, rapport « serveur » figé.
///
/// Reproduit le contrat : liste des champs manquants dans l'ordre serveur,
/// métabolisme calculé uniquement quand le profil est complet (valeurs de
/// référence du calculateur : homme, 30 ans, 180 cm, 80 kg, modéré).
class FakeNutritionRepository implements NutritionRepository {
  FakeNutritionRepository({
    this.weightKg,
    this._sex,
    this._birthDate,
    this._heightCm,
    this._activityLevel,
    this._goal,
    this.failure,
  });

  /// L'échec que le « serveur » oppose au rapport métabolique.
  ///
  /// Sans lui, aucun test ne pouvait distinguer « profil vide » de « serveur
  /// muet » — et c'est exactement la confusion que l'accueil commettait.
  final Object? failure;

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
    final refused = failure;
    if (refused != null) {
      throw refused;
    }
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

  /// La base d'aliments du « serveur », par code ; vide, elle se comporte
  /// comme une base pas encore importée (version nulle).
  final Map<int, Food> foods = {};

  /// L'échec que le « serveur » oppose à la lecture d'UN repas.
  Object? mealReadFailure;

  /// L'échec qu'il oppose à la prochaine écriture (création, correction,
  /// suppression) ; consommé par elle.
  Object? writeFailure;

  /// Chaque écriture TENTÉE, dans l'ordre, refusées comprises :
  /// l'identifiant et ce qui a été envoyé.
  final List<({String id, MealWrite write})> writes = [];

  /// Retient chaque écriture (création, correction, suppression) jusqu'à ce
  /// que le test complète ce compléteur : un réseau lent, pendant lequel
  /// l'écran doit tenir.
  Completer<void>? writeHold;

  /// L'échec opposé APRÈS la prochaine écriture, qui a donc bien eu lieu :
  /// la réponse s'est perdue en route (délai dépassé, coupure) ; consommé.
  Object? lostResponse;

  /// Chaque lecture d'UN repas, dans l'ordre.
  final List<String> mealReads = [];

  Future<void> _arrive() async {
    final held = writeHold;
    if (held != null) {
      await held.future;
    }
    _consumeFailure();
  }

  void _depart() {
    final lost = lostResponse;
    if (lost != null) {
      lostResponse = null;
      throw lost;
    }
  }

  @override
  Future<List<MealEntry>> mealsBetween(DateTime from, DateTime to) async =>
      meals
          .where(
            (meal) => !meal.eatenAt.isBefore(from) && meal.eatenAt.isBefore(to),
          )
          .toList()
        ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));

  @override
  Future<MealDetail> meal(String id) async {
    mealReads.add(id);
    final refused = mealReadFailure;
    if (refused != null) {
      throw refused;
    }
    final found = _find(id);
    return (
      meal: found,
      attribution: found.components.isEmpty ? null : _attribution,
    );
  }

  @override
  Future<MealEntry> addMeal(String id, MealWrite write) async {
    writes.add((id: id, write: write));
    await _arrive();
    final existing = meals.where((meal) => meal.id == id);
    if (existing.isNotEmpty) {
      // Création idempotente, comme le serveur : un envoi rejoué rend le
      // repas DÉJÀ écrit, sans rien réécrire de ce qui arrive.
      return existing.first;
    }
    final added = _written(id, write, previous: null);
    meals.add(added);
    _depart();
    return added;
  }

  @override
  Future<MealEntry> updateMeal(String id, MealWrite write) async {
    writes.add((id: id, write: write));
    await _arrive();
    final index = meals.indexWhere((meal) => meal.id == id);
    final previous = _find(id);
    final content = write.content;
    if (previous.components.isNotEmpty &&
        content is ManualMealContent &&
        !content.clearsComposition) {
      // Comme le serveur : des totaux à la main sur un repas COMPOSÉ, sans
      // en retirer la composition, sont refusés.
      throw const ServerException('Retire d’abord sa composition.');
    }
    final corrected = _written(id, write, previous: previous);
    meals[index] = corrected;
    _depart();
    return corrected;
  }

  @override
  Future<void> deleteMeal(String id) async {
    await _arrive();
    meals.removeWhere((meal) => meal.id == id);
    // Comme le serveur : la photo part avec le repas.
    photos.remove(id);
    _depart();
  }

  /// Les recherches reçues, dans l'ordre.
  final List<String> searches = [];

  /// L'échec que le « serveur » oppose à la prochaine recherche ; consommé
  /// par elle.
  Object? searchFailure;

  /// Retient la réponse à la recherche [query] jusqu'à ce que le test
  /// complète ce compléteur : de quoi faire arriver une réponse lente APRÈS
  /// une plus récente.
  final Map<String, Completer<void>> heldSearches = {};

  @override
  Future<FoodSearchResult> searchFoods(String query, {int limit = 20}) async {
    searches.add(query);
    final held = heldSearches[query];
    if (held != null) {
      await held.future;
    }
    final refused = searchFailure;
    if (refused != null) {
      searchFailure = null;
      throw refused;
    }
    final words = query.toLowerCase().split(' ').where((w) => w.isNotEmpty);
    return (
      foods: foods.values
          .where((food) => words.every(food.name.toLowerCase().contains))
          .take(limit)
          .toList(),
      source: _source,
    );
  }

  @override
  Future<FoodDetail> food(int code) async {
    final found = foods[code];
    if (found == null) {
      throw const ServerException('Aliment introuvable.', statusCode: 404);
    }
    return (food: found, source: _source);
  }

  /// Les photos du « serveur », par repas : les octets tels qu'ils ont été
  /// reçus.
  final Map<String, Uint8List> photos = {};

  /// Chaque lecture de photo, par repas, dans l'ordre.
  final List<String> photoReads = [];

  /// L'échec opposé au prochain envoi (ou retrait) de photo ; consommé.
  Object? photoFailure;

  /// Chaque dépôt et chaque retrait de photo, dans l'ordre (`null` pour un
  /// retrait), refusés compris.
  final List<({String id, Uint8List? jpeg})> photoWrites = [];

  /// Retient chaque lecture de photo jusqu'à ce que le test complète ce
  /// compléteur : une photo qui tarde à venir.
  Completer<void>? photoReadHold;

  /// L'échec opposé à chaque lecture de photo (hors connexion, par exemple).
  Object? photoReadFailure;

  @override
  Future<Uint8List?> mealPhoto(String id) async {
    photoReads.add(id);
    final held = photoReadHold;
    if (held != null) {
      await held.future;
    }
    final refused = photoReadFailure;
    if (refused != null) {
      throw refused;
    }
    return photos[id];
  }

  @override
  Future<MealEntry> replaceMealPhoto(String id, Uint8List jpeg) async {
    photoWrites.add((id: id, jpeg: jpeg));
    _consumePhotoFailure();
    final index = meals.indexWhere((meal) => meal.id == id);
    final meal = _find(id);
    photos[id] = jpeg;
    final updated = _withPhoto(meal, DateTime.now().toUtc());
    meals[index] = updated;
    return updated;
  }

  @override
  Future<void> removeMealPhoto(String id) async {
    photoWrites.add((id: id, jpeg: null));
    _consumePhotoFailure();
    final index = meals.indexWhere((meal) => meal.id == id);
    photos.remove(id);
    if (index >= 0) {
      meals[index] = _withPhoto(meals[index], null);
    }
  }

  void _consumePhotoFailure() {
    final refused = photoFailure;
    if (refused != null) {
      photoFailure = null;
      throw refused;
    }
  }

  static MealEntry _withPhoto(MealEntry meal, DateTime? photoUpdatedAt) =>
      MealEntry(
        id: meal.id,
        name: meal.name,
        kcal: meal.kcal,
        eatenAt: meal.eatenAt,
        moment: meal.moment,
        quantity: meal.quantity,
        quantityUnit: meal.quantityUnit,
        proteinG: meal.proteinG,
        carbsG: meal.carbsG,
        fatG: meal.fatG,
        components: meal.components,
        computed: meal.computed,
        photoUpdatedAt: photoUpdatedAt,
      );

  FoodSource get _source => FoodSource(
    attribution: _attribution.attribution,
    license: _attribution.license,
    url: _attribution.url,
    version: foods.isEmpty ? null : '2020-07-07',
  );

  static const _attribution = FoodAttribution(
    attribution:
        'Source : Anses, Table de composition nutritionnelle des aliments '
        'Ciqual',
    license: 'Licence Ouverte Etalab 2.0',
    url: 'https://ciqual.anses.fr/',
  );

  /// Même réponse que le serveur : introuvable, sans dire pourquoi.
  MealEntry _find(String id) {
    for (final meal in meals) {
      if (meal.id == id) {
        return meal;
      }
    }
    throw const ServerException('Repas introuvable.', statusCode: 404);
  }

  void _consumeFailure() {
    final refused = writeFailure;
    if (refused != null) {
      writeFailure = null;
      throw refused;
    }
  }

  /// Le repas tel que le « serveur » l'écrit : les totaux saisis, ou ceux
  /// qu'il CALCULE depuis les aliments (ligne gardée : son instantané ;
  /// ligne neuve : la base).
  MealEntry _written(String id, MealWrite write, {MealEntry? previous}) {
    final content = write.content;
    MealEntry entry({
      required int kcal,
      int? proteinG,
      int? carbsG,
      int? fatG,
      double? quantity,
      MealQuantityUnit? unit,
      List<MealComponent> components = const [],
    }) => MealEntry(
      id: id,
      name: write.name,
      moment: write.moment,
      kcal: kcal,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      quantity: quantity,
      quantityUnit: unit,
      eatenAt: write.eatenAt.toUtc(),
      components: components,
      computed: components.isNotEmpty,
      photoUpdatedAt: previous?.photoUpdatedAt,
    );

    switch (content) {
      case ManualMealContent():
        return entry(
          kcal: content.kcal,
          proteinG: content.proteinG,
          carbsG: content.carbsG,
          fatG: content.fatG,
          quantity: content.quantity,
          unit: content.quantityUnit,
        );
      case KeptCompositionContent():
        final kept = previous!;
        return entry(
          kcal: kept.kcal,
          proteinG: kept.proteinG,
          carbsG: kept.carbsG,
          fatG: kept.fatG,
          quantity: kept.quantity,
          unit: kept.quantityUnit,
          components: kept.components,
        );
      case ComposedMealContent(:final components):
        final lines = [
          for (final input in components) _lineFor(input, previous),
        ];
        final totals = compositionPreview(lines);
        return entry(
          kcal: totals.kcal,
          proteinG: totals.proteinG,
          carbsG: totals.carbsG,
          fatG: totals.fatG,
          quantity: totals.quantityG,
          unit: MealQuantityUnit.gram,
          components: [for (final line in lines) _componentOf(line)],
        );
    }
  }

  MealLine _lineFor(MealComponentInput input, MealEntry? previous) {
    for (final kept in previous?.components ?? const <MealComponent>[]) {
      if (kept.id == input.id) {
        return MealLine.fromComponent(kept).withQuantity(input.quantityG);
      }
    }
    final food = foods[input.foodCode];
    if (food == null) {
      throw ServerException('Aliment inconnu : ${input.foodCode}.');
    }
    return MealLine.fromFood(
      id: input.id,
      food: food,
      quantityG: input.quantityG,
      sourceVersion: '2020-07-07',
    );
  }

  static MealComponent _componentOf(MealLine line) {
    double? tenth(double? per100g) => per100g == null
        ? null
        : (per100g * line.quantityG / 100 * 10).round() / 10;
    return MealComponent(
      id: line.id,
      foodCode: line.foodCode,
      name: line.name,
      shortName: line.shortName,
      group: line.group,
      sourceVersion: line.sourceVersion,
      quantityG: line.quantityG,
      kcal: tenth(line.per100g.kcal)!,
      proteinG: tenth(line.per100g.proteinG),
      carbsG: tenth(line.per100g.carbsG),
      fatG: tenth(line.per100g.fatG),
    );
  }
}
