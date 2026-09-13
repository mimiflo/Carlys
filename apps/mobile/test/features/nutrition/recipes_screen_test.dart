import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/recipe.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/recipes_controllers.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/recipes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'écran Recettes : deux volets, le premier partagé sucré/salé, et
/// l'adaptation au profil qui CLASSE sans rien cacher.
///
/// Le pack est surchargé par des recettes fixes : ce test éprouve l'écran,
/// pas le contenu éditorial, qui a sa propre garde d'intégrité.
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
    summary: 'résumé de $id',
    minutes: 10,
    kcal: kcal,
    proteinG: 20,
    carbsG: 40,
    fatG: 10,
    goals: goals,
    ingredients: const ['200 g de quelque chose'],
    steps: const ['Fais cuire.'],
  );
}

final _pack = [
  _recipe(
    'porridge',
    moment: RecipeMoment.petitDejCollation,
    saveur: RecipeSaveur.sucre,
  ),
  _recipe(
    'omelette',
    moment: RecipeMoment.petitDejCollation,
    saveur: RecipeSaveur.sale,
  ),
  _recipe('salade', moment: RecipeMoment.repas),
  _recipe(
    'poulet-riz',
    moment: RecipeMoment.repas,
    goals: const [NutritionGoal.gainMuscle],
    kcal: 600,
  ),
];

Widget _app({NutritionGoal? goal, int? targetKcal}) {
  return ProviderScope(
    overrides: [
      recipesPackProvider.overrideWith((ref) async => _pack),
      nutritionGoalProvider.overrideWith((ref) => goal),
      targetKcalProvider.overrideWith((ref) => targetKcal),
    ],
    child: const MaterialApp(home: RecipesScreen()),
  );
}

void main() {
  testWidgets('après un échec de lecture, « Réessayer » rouvre le livre', (
    tester,
  ) async {
    // CE QUE CE TEST PROTÈGE : `recipesPackProvider` n'est pas `autoDispose`.
    // Sans bouton de reprise, un unique échec resterait mémoïsé et l'écran
    // serait mort jusqu'à la fin de la session, même en le quittant et en le
    // rouvrant. Le bouton doit donc réellement relancer la lecture.
    var appels = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recipesPackProvider.overrideWith((ref) async {
            appels += 1;
            if (appels == 1) {
              throw Exception('asset illisible');
            }
            return _pack;
          }),
          nutritionGoalProvider.overrideWith((ref) => null),
          targetKcalProvider.overrideWith((ref) => null),
        ],
        child: const MaterialApp(home: RecipesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recettes indisponibles'), findsOneWidget);
    expect(find.text('porridge'), findsNothing);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(appels, 2, reason: 'la lecture doit être RELANCÉE, pas resservie');
    expect(find.text('Recettes indisponibles'), findsNothing);
    expect(find.text('porridge'), findsOneWidget);
  });

  testWidgets('ouvre sur le petit-déj sucré, et bascule en salé', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('porridge'), findsOneWidget);
    expect(find.text('omelette'), findsNothing);

    await tester.tap(find.text('Salé'));
    await tester.pumpAndSettle();

    expect(find.text('omelette'), findsOneWidget);
    expect(find.text('porridge'), findsNothing);
  });

  testWidgets('le volet repas n’offre PAS le partage sucré/salé', (
    tester,
  ) async {
    // Trancher la saveur d'un déjeuner n'aide personne à choisir un plat :
    // les pastilles disparaissent sur ce volet.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Sucré'), findsOneWidget);

    await tester.tap(find.text('Déjeuner & dîner'));
    await tester.pumpAndSettle();

    expect(find.text('Sucré'), findsNothing);
    expect(find.text('Salé'), findsNothing);
    expect(find.text('salade'), findsOneWidget);
    expect(find.text('poulet-riz'), findsOneWidget);
  });

  testWidgets(
    'l’objectif met la recette devant, sans faire disparaître l’autre',
    (tester) async {
      await tester.pumpWidget(_app(goal: NutritionGoal.gainMuscle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Déjeuner & dîner'));
      await tester.pumpAndSettle();

      // Les deux sont là — l'adaptation classe, elle ne filtre pas.
      expect(find.text('poulet-riz'), findsOneWidget);
      expect(find.text('salade'), findsOneWidget);
      // Et celle qui sert l'objectif est annoncée comme telle.
      expect(find.text('Pour ton objectif'), findsOneWidget);
      // Celle qui sert l'objectif est plus HAUTE à l'écran.
      final yPoulet = tester.getTopLeft(find.text('poulet-riz')).dy;
      final ySalade = tester.getTopLeft(find.text('salade')).dy;
      expect(yPoulet, lessThan(ySalade));
    },
  );

  testWidgets('sans profil, aucune part de journée n’est annoncée', (
    tester,
  ) async {
    // Sans cible calorique, ce rapport n'existe pas : on se tait plutôt que
    // d'inventer un pourcentage.
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.textContaining('DE TA JOURNÉE'), findsNothing);
    expect(find.textContaining('Classées pour ton objectif'), findsNothing);
  });

  testWidgets('avec une cible, chaque recette dit ce qu’elle y pèse', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(goal: NutritionGoal.maintain, targetKcal: 2000),
    );
    await tester.pumpAndSettle();

    // 400 kcal sur une cible de 2000 : 20 % de la journée.
    expect(find.text('20 % DE TA JOURNÉE'), findsOneWidget);
    expect(find.textContaining('Classées pour ton objectif'), findsOneWidget);
  });

  testWidgets('une recette se déplie : ingrédients puis préparation', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Repliée : les étapes sont RETIRÉES de l'arbre, pas masquées.
    expect(find.text('Fais cuire.'), findsNothing);

    await tester.tap(find.text('porridge'));
    await tester.pumpAndSettle();

    expect(find.text('200 g de quelque chose'), findsOneWidget);
    expect(find.text('Fais cuire.'), findsOneWidget);
  });
}
