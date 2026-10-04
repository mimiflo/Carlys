import 'package:carlys_mobile/core/utilities/civil_days.dart';
import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/meal_entry.dart';
import 'package:carlys_mobile/features/nutrition/domain/services/day_intake.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/daily_goals_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_nutrition_repository.dart';

/// L'onglet Nutrition : ce qui a été mangé, sur ce que vise le profil.
void main() {
  MealEntry repas(int kcal, {int? protein, int? carbs, int? fat}) => MealEntry(
    id: '$kcal',
    name: 'Repas',
    kcal: kcal,
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
    eatenAt: DateTime.utc(2026, 10, 3, 12),
  );

  group('dayIntake', () {
    test('additionne les repas, sans inventer une macro inconnue', () {
      final total = dayIntake([
        repas(482, protein: 28, carbs: 62, fat: 12),
        repas(172, carbs: 30),
      ]);
      expect(total, (kcal: 654, proteinG: 28, carbsG: 92, fatG: 12));
    });

    test('une journée vide vaut zéro', () {
      expect(dayIntake(const []), (kcal: 0, proteinG: 0, carbsG: 0, fatG: 0));
    });
  });

  test('le jour choisi se compte en jours civils, heure d’été comprise', () {
    // En heure locale, du 29 au 30 mars 2026 il n'y a que 23 heures à Paris.
    expect(joursCivilsEntre(DateTime(2026, 3, 30), DateTime(2026, 3, 29)), -1);
    expect(
      joursCivilsEntre(DateTime(2026, 10, 25), DateTime(2026, 10, 24, 23)),
      -1,
    );
    expect(joursCivilsEntre(DateTime(2026, 3, 30), DateTime(2026, 3, 30)), 0);
  });

  group('DailyGoalsCard', () {
    Future<void> pump(WidgetTester tester, DayIntake intake) =>
        tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            // Dans une page qui défile, comme dans l'onglet.
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: DailyGoalsCard(
                  target: FakeNutritionRepository.referenceResult,
                  intake: intake,
                ),
              ),
            ),
          ),
        );

    testWidgets('mangé sur visé, pour chaque valeur, et ce qui reste', (
      tester,
    ) async {
      await pump(tester, (kcal: 654, proteinG: 42, carbsG: 68, fatG: 22));

      expect(find.text('Tes objectifs du jour'), findsOneWidget);
      expect(find.text('24 %'), findsOneWidget);
      expect(find.text('654 / ${formatThousands(2759)} kcal'), findsOneWidget);
      expect(find.text('42 / 128 g'), findsOneWidget);
      expect(find.text('68 / 389 g'), findsOneWidget);
      expect(find.text('22 / 77 g'), findsOneWidget);
      expect(
        find.text('${formatThousands(2105)} kcal\nrestantes'),
        findsOneWidget,
      );
    });

    testWidgets('au-delà de l’objectif : le dépassement se dit', (
      tester,
    ) async {
      await pump(tester, (kcal: 3000, proteinG: 0, carbsG: 0, fatG: 0));
      expect(find.text('241 kcal\nau-delà'), findsOneWidget);
    });

    testWidgets('320 points, texte doublé : rien ne déborde', (tester) async {
      tester.view.physicalSize = const Size(960, 2400);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(tester, (kcal: 654, proteinG: 42, carbsG: 68, fatG: 22));
      expect(tester.takeException(), isNull);
    });
  });
}
