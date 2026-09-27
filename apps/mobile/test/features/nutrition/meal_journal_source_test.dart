import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';
import '../../support/meal_editor_app.dart';
import '../../support/sample_meals.dart';

/// LE JOURNAL MONTRE LA MENTION DE LA BASE quand un repas en porte les
/// valeurs.
///
/// Ses tuiles affichent des totaux calculés depuis la table CIQUAL. L'API
/// sert la mention avec la liste du jour ; le mobile la jetait, alors que
/// les CGU promettent qu'elle accompagne ces valeurs.
void main() {
  final now = DateTime.now();
  final midi = DateTime(now.year, now.month, now.day, 12, 30);

  testWidgets('un repas composé au journal : la mention, version comprise', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()
      ..meals.add(composedLunch(eatenAt: midi));
    await pumpMealApp(tester, nutrition);

    expect(find.textContaining('Table de composition'), findsOneWidget);
    expect(find.textContaining('Etalab 2.0'), findsOneWidget);
  });

  testWidgets('seulement des repas saisis à la main : pas de mention', (
    tester,
  ) async {
    final nutrition = FakeNutritionRepository()
      ..meals.add(manualBreakfast(eatenAt: midi));
    await pumpMealApp(tester, nutrition);

    expect(find.textContaining('Etalab'), findsNothing);
  });
}
