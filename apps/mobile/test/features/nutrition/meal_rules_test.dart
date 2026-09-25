import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/services/meal_composition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/utils/meal_editor_state.dart';
import 'package:carlys_mobile/features/nutrition/presentation/utils/meal_editor_validation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/sample_meals.dart';

/// LES RÈGLES PURES de l'écran de repas : le moment proposé, l'aperçu des
/// totaux, la famille d'un aliment, les fautes de saisie, et ce qui part au
/// serveur.
void main() {
  MealLine line(String id, Food food, double grams) =>
      MealLine.fromFood(id: id, food: food, quantityG: grams);

  group('le moment proposé d’après l’heure', () {
    MealMoment at(int hour, int minute) =>
        MealMoment.suggestFor(DateTime(2026, 9, 25, hour, minute));

    test('cinq plages, bornes basses incluses', () {
      expect(at(7, 45), MealMoment.breakfast);
      expect(at(10, 29), MealMoment.breakfast);
      expect(at(10, 30), MealMoment.lunch);
      expect(at(14, 59), MealMoment.lunch);
      expect(at(15, 0), MealMoment.snack);
      expect(at(17, 59), MealMoment.snack);
      expect(at(18, 0), MealMoment.dinner);
      expect(at(22, 29), MealMoment.dinner);
      expect(at(22, 30), MealMoment.snack);
      expect(at(23, 59), MealMoment.snack);
    });

    test('avant 10 h 30, même la nuit : le premier repas de la journée', () {
      expect(at(0, 0), MealMoment.breakfast);
      expect(at(3, 15), MealMoment.breakfast);
    });

    test('un repas enregistré garde SON moment, quelle que soit l’heure', () {
      final diner = MealEntry(
        id: 'x',
        name: 'Pâtes',
        kcal: 600,
        moment: MealMoment.dinner,
        eatenAt: DateTime(2026, 9, 25, 23, 40).toUtc(),
      );
      expect(diner.displayedMoment, MealMoment.dinner);
    });

    test('les libellés et les valeurs du serveur', () {
      expect(MealMoment.values.map((m) => m.label), [
        'Petit-déjeuner',
        'Déjeuner',
        'Dîner',
        'Collation',
      ]);
      expect(MealMoment.fromApi('SNACK'), MealMoment.snack);
      expect(MealMoment.fromApi(null), isNull);
      expect(MealMoment.fromApi('BRUNCH'), isNull);
    });
  });

  group('l’aperçu des totaux, la règle du serveur', () {
    test('le repas de la maquette : 320 g, 390 kcal, 40 / 44 / 5 g', () {
      final totals = compositionPreview([
        line('a', pouletCuit, 120),
        line('b', rizBlancCuit, 150),
        line('c', brocoliCuit, 50),
      ]);

      // 180 + 195 + 14,75 = 389,75, arrondi UNE fois : 390.
      expect(totals.kcal, 390);
      expect(totals.proteinG, 40);
      expect(totals.carbsG, 44);
      expect(totals.fatG, 5);
      expect(totals.quantityG, 320);
    });

    test('une macro qu’UN aliment ignore rend le total inconnu, pas 0', () {
      final totals = compositionPreview([
        line('a', pouletCuit, 120),
        line('b', galetteRiz, 20),
      ]);

      expect(totals.fatG, isNull);
      expect(totals.proteinG, isNotNull);
      expect(totals.kcal, 258); // 180 + 78
    });

    test('un demi s’arrondit vers le haut, même quand le flottant hésite', () {
      // 0,1 + 0,2 ne vaut pas 0,3 en double : l'arrondi ne doit pas en
      // dépendre.
      expect(roundHalfUp(12.5), 13);
      expect(roundHalfUp(12.499999999), 13);
      expect(roundHalfUp(12.49), 12);
      expect(roundHalfUp(0.1 + 0.2 + 0.2), 1);
    });

    test('une ligne enregistrée : ses valeurs pour 100 g se DÉDUISENT', () {
      final saved = componentOf('ligne', pouletCuit, 120);
      final reloaded = MealLine.fromComponent(saved);

      expect(reloaded.per100g.kcal, closeTo(150, 0.01));
      // 120 g → 200 g : l'aperçu suit la quantité, sans relire la base.
      final totals = compositionPreview([reloaded.withQuantity(200)]);
      expect(totals.kcal, 300);
      expect(totals.proteinG, 58);
    });
  });

  group('la famille d’un aliment, d’après son groupe CIQUAL', () {
    test('les groupes de la table', () {
      expect(
        FoodFamily.fromGroup('viandes, œufs, poissons et assimilés'),
        FoodFamily.proteins,
      );
      expect(
        FoodFamily.fromGroup('fruits, légumes, légumineuses et oléagineux'),
        FoodFamily.plants,
      );
      expect(FoodFamily.fromGroup('produits céréaliers'), FoodFamily.cereals);
      expect(
        FoodFamily.fromGroup('produits laitiers et assimilés'),
        FoodFamily.dairy,
      );
      expect(
        FoodFamily.fromGroup('eaux et autres boissons'),
        FoodFamily.drinks,
      );
      expect(FoodFamily.fromGroup('glaces et sorbets'), FoodFamily.frozen);
      expect(FoodFamily.fromGroup('produits sucrés'), FoodFamily.sweets);
      expect(FoodFamily.fromGroup('matières grasses'), FoodFamily.fats);
      expect(
        FoodFamily.fromGroup('entrées et plats composés'),
        FoodFamily.dishes,
      );
      expect(
        FoodFamily.fromGroup('aides culinaires et ingrédients divers'),
        FoodFamily.pantry,
      );
      expect(FoodFamily.fromGroup('aliments infantiles'), FoodFamily.infant);
    });

    test('un groupe absent ou inconnu : « autre », jamais une devinette', () {
      expect(FoodFamily.fromGroup(null), FoodFamily.other);
      expect(FoodFamily.fromGroup('  '), FoodFamily.other);
      expect(FoodFamily.fromGroup('compléments'), FoodFamily.other);
    });
  });

  group('les fautes de saisie', () {
    MealEditorState manual({
      String name = 'Riz',
      String kcal = '650',
      String protein = '',
      String quantity = '',
    }) => MealEditorState.fresh(id: 'id', eatenAt: DateTime(2026, 9, 25, 12))
        .copyWith(
          name: name,
          kcalText: kcal,
          proteinText: protein,
          quantityText: quantity,
        );

    test('une saisie complète n’a aucune faute', () {
      expect(validateMealEditor(manual()).isEmpty, isTrue);
    });

    test('le nom et les calories sont obligatoires', () {
      final errors = validateMealEditor(manual(name: '  ', kcal: ''));
      expect(errors.name, 'Nomme ton repas.');
      expect(errors.kcal, 'Calories : entre 1 et 10 000.');
    });

    test('les bornes du serveur : 10 000 kcal, 1 000 g par macro', () {
      expect(validateMealEditor(manual(kcal: '10001')).kcal, isNotNull);
      expect(validateMealEditor(manual(kcal: '0')).kcal, isNotNull);
      expect(
        validateMealEditor(manual(protein: '1001')).protein,
        'Protéines : entre 0 et 1 000 g.',
      );
      // Zéro protéine est une information : il s'accepte.
      expect(validateMealEditor(manual(protein: '0')).protein, isNull);
    });

    test('la quantité : virgule française, deux décimales au plus', () {
      expect(validateMealEditor(manual(quantity: '1,5')).quantity, isNull);
      expect(validateMealEditor(manual(quantity: '1,555')).quantity, isNotNull);
      expect(validateMealEditor(manual(quantity: '0')).quantity, isNotNull);
      expect(validateMealEditor(manual(quantity: '10000')).quantity, isNotNull);
    });

    test('un repas composé ne vérifie que son nom : le serveur calcule', () {
      final composed = manual(
        kcal: '',
      ).copyWith(lines: [line('a', pouletCuit, 120)]);
      expect(validateMealEditor(composed).isEmpty, isTrue);
    });

    test('la quantité d’un aliment : 1 à 5 000 g', () {
      expect(componentQuantityError('120'), isNull);
      expect(componentQuantityError('0,5'), isNotNull);
      expect(componentQuantityError('5001'), isNotNull);
      expect(componentQuantityError('abc'), isNotNull);
    });
  });

  group('ce qui part au serveur', () {
    final noon = DateTime(2026, 9, 25, 12, 30);

    test('un repas composé intact : la composition est GARDÉE', () {
      final state = MealEditorState.fromMeal(
        composedLunch(eatenAt: noon),
      ).copyWith(name: 'Déjeuner du mardi');

      final write = state.toWrite();

      expect(write.content, isA<KeptCompositionContent>());
      expect(write.name, 'Déjeuner du mardi');
    });

    test('recomposé : les lignes, sous leurs identifiants d’origine', () {
      final meal = composedLunch(eatenAt: noon);
      final state = MealEditorState.fromMeal(meal);
      final kept = state.lines.first.withQuantity(200);

      final write = state.copyWith(lines: [kept], linesChanged: true).toWrite();

      final content = write.content as ComposedMealContent;
      expect(content.components.single.id, meal.components.first.id);
      expect(content.components.single.quantityG, 200);
    });

    test('saisi à la main : les cases lues, vide = inconnu', () {
      final state = MealEditorState.fresh(id: 'id', eatenAt: noon).copyWith(
        name: ' Riz complet ',
        kcalText: '650',
        carbsText: '80',
        quantityText: '1,5',
        unit: MealQuantityUnit.portion,
      );

      final write = state.toWrite();

      final content = write.content as ManualMealContent;
      expect(write.name, 'Riz complet');
      expect(content.kcal, 650);
      expect(content.carbsG, 80);
      expect(content.proteinG, isNull);
      expect(content.quantity, 1.5);
      expect(content.quantityUnit, MealQuantityUnit.portion);
      expect(content.clearsComposition, isFalse);
    });

    test('sans quantité, l’unité ne part pas : la paire est indivisible', () {
      final state = MealEditorState.fresh(
        id: 'id',
        eatenAt: noon,
      ).copyWith(name: 'Riz', kcalText: '650');

      final content = state.toWrite().content as ManualMealContent;
      expect(content.quantity, isNull);
      expect(content.quantityUnit, isNull);
    });

    test('un repas sans moment reçoit celui qu’on lui a proposé', () {
      final state = MealEditorState.fromMeal(
        oldMealWithoutMoment(eatenAt: DateTime(2026, 9, 20, 20)),
      );

      expect(state.moment, isNull);
      expect(state.toWrite().moment, MealMoment.dinner);
    });

    test('les quantités s’écrivent à la française dans les cases', () {
      expect(formatQuantityInput(320), '320');
      expect(formatQuantityInput(1.5), '1,5');
      expect(formatQuantityInput(1.25), '1,25');
      expect(formatQuantityInput(null), '');
      expect(parseDecimalInput('1,5'), 1.5);
      expect(parseDecimalInput(' '), isNull);
    });
  });
}
