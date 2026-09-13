import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/recipe.dart';
import 'package:carlys_mobile/features/nutrition/domain/recipe_selection.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : la règle « adaptée au profil ». Elle classe,
/// elle ne CACHE pas — c'est la décision de conception, et sans test elle se
/// transformerait en filtre au premier remaniement, vidant des volets entiers.
Recipe _recipe(
  String id, {
  required RecipeMoment moment,
  RecipeSaveur? saveur,
  List<NutritionGoal> goals = const [],
  int kcal = 400,
}) {
  return Recipe(
    id: id,
    moment: moment,
    saveur: saveur,
    title: id,
    summary: 'résumé',
    minutes: 10,
    kcal: kcal,
    proteinG: 20,
    carbsG: 40,
    fatG: 10,
    goals: goals,
    ingredients: const ['un ingrédient'],
    steps: const ['une étape'],
  );
}

void main() {
  final pdjSucre = _recipe(
    'pdj-sucre',
    moment: RecipeMoment.petitDejCollation,
    saveur: RecipeSaveur.sucre,
    goals: const [NutritionGoal.loseWeight],
  );
  final pdjSale = _recipe(
    'pdj-sale',
    moment: RecipeMoment.petitDejCollation,
    saveur: RecipeSaveur.sale,
    goals: const [NutritionGoal.gainMuscle],
  );
  final repasLeger = _recipe(
    'repas-leger',
    moment: RecipeMoment.repas,
    goals: const [NutritionGoal.loseWeight],
  );
  final repasDense = _recipe(
    'repas-dense',
    moment: RecipeMoment.repas,
    goals: const [NutritionGoal.gainMuscle],
  );
  final toutes = [pdjSucre, pdjSale, repasLeger, repasDense];

  test('le volet petit-déj se partage en sucré et salé', () {
    expect(
      recipesFor(
        toutes,
        moment: RecipeMoment.petitDejCollation,
        saveur: RecipeSaveur.sucre,
      ).map((recipe) => recipe.id),
      ['pdj-sucre'],
    );
    expect(
      recipesFor(
        toutes,
        moment: RecipeMoment.petitDejCollation,
        saveur: RecipeSaveur.sale,
      ).map((recipe) => recipe.id),
      ['pdj-sale'],
    );
  });

  test('le volet repas ignore la saveur : aucun repas n’en déclare', () {
    expect(recipesFor(toutes, moment: RecipeMoment.repas).map((r) => r.id), [
      'repas-leger',
      'repas-dense',
    ]);
  });

  test('l’objectif CLASSE, il ne cache rien', () {
    // LE test de ce fichier. Avec « prendre du muscle », le repas dense passe
    // devant — mais le repas léger reste là : quelqu'un qui prend du muscle a
    // le droit de vouloir une assiette légère.
    final pourMuscle = recipesFor(
      toutes,
      moment: RecipeMoment.repas,
      goal: NutritionGoal.gainMuscle,
    );

    expect(pourMuscle.map((r) => r.id), ['repas-dense', 'repas-leger']);
    expect(
      pourMuscle,
      hasLength(2),
      reason: 'aucune recette ne disparaît à cause de l’objectif',
    );
  });

  test('sans objectif connu, l’ordre du pack est conservé', () {
    // Profil incomplet : on ne réordonne pas au hasard, on sert le pack tel
    // qu'il a été écrit.
    expect(recipesFor(toutes, moment: RecipeMoment.repas).map((r) => r.id), [
      'repas-leger',
      'repas-dense',
    ]);
  });

  test('le classement est STABLE à l’intérieur de chaque groupe', () {
    final a = _recipe('a', moment: RecipeMoment.repas, goals: const []);
    final b = _recipe(
      'b',
      moment: RecipeMoment.repas,
      goals: const [NutritionGoal.maintain],
    );
    final c = _recipe('c', moment: RecipeMoment.repas, goals: const []);
    final d = _recipe(
      'd',
      moment: RecipeMoment.repas,
      goals: const [NutritionGoal.maintain],
    );

    // Sans stabilité, l'ordre changerait d'un affichage à l'autre sans que
    // rien ne l'explique à l'écran.
    expect(
      recipesFor(
        [a, b, c, d],
        moment: RecipeMoment.repas,
        goal: NutritionGoal.maintain,
      ).map((r) => r.id),
      ['b', 'd', 'a', 'c'],
    );
  });

  group('part de la journée', () {
    test('se tait quand la cible est inconnue', () {
      // Sans profil complet, ce rapport n'existe pas : en inventer un serait
      // pire que de se taire.
      expect(repasLeger.shareOfTargetPercent(null), isNull);
      expect(repasLeger.shareOfTargetPercent(0), isNull);
    });

    test('rapporte les calories à la cible', () {
      expect(
        _recipe(
          'x',
          moment: RecipeMoment.repas,
          kcal: 500,
        ).shareOfTargetPercent(2000),
        25,
      );
    });
  });
}
