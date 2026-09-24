import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_program/presentation/widgets/program_day_sheet.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/presentation/controllers/workout_template_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// « Activité libre… » dans la feuille d'une case du programme : le libellé
/// se saisit dans la popup centrée (`showAppPrompt`), plus dans une boîte de
/// dialogue Material. La feuille, elle, reste une feuille : c'est un menu.
void main() {
  late BuildContext screen;

  Future<Future<ProgramDayChoice?>> openFreeActivity(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutTemplatesProvider.overrideWith(
            (ref) => Stream.value(const <WorkoutTemplateInfo>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                screen = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    final choice = showProgramDaySheet(screen, hasExisting: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activité libre…'));
    await tester.pumpAndSettle();

    final card = find.byType(AppPopupCard);
    expect(
      find.descendant(of: card, matching: find.text('Activité libre')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Course, vélo, yoga…')),
      findsOneWidget,
    );
    return choice;
  }

  Finder popupButton(String label) => find.descendant(
    of: find.byType(AppPopupCard),
    matching: find.widgetWithText(AppButton, label),
  );

  Finder field() => find.descendant(
    of: find.byType(AppPopupCard),
    matching: find.byType(TextField),
  );

  testWidgets('le libellé validé, sans ses espaces, remplit la case', (
    tester,
  ) async {
    final choice = await openFreeActivity(tester);

    await tester.enterText(field(), '  Yoga  ');
    await tester.pump();
    await tester.tap(popupButton('Valider'));
    await tester.pumpAndSettle();

    final result = await choice;
    expect(result, isA<FreeDayChoice>());
    expect((result! as FreeDayChoice).label, 'Yoga');
    expect(find.text('Ce jour-là'), findsNothing);
  });

  testWidgets('la saisie est bornée à 120 caractères, comme avant', (
    tester,
  ) async {
    await openFreeActivity(tester);

    expect(tester.widget<TextField>(field()).maxLength, 120);
  });

  testWidgets('renoncer ne choisit rien et laisse la feuille ouverte', (
    tester,
  ) async {
    final choice = await openFreeActivity(tester);
    var settled = false;
    unawaited(choice.then((_) => settled = true));

    await tester.enterText(field(), 'Yoga');
    await tester.pump();
    await tester.tap(popupButton('Annuler'));
    await tester.pumpAndSettle();

    expect(find.byType(AppPopupCard), findsNothing);
    expect(find.text('Ce jour-là'), findsOneWidget);
    expect(settled, isFalse);
  });
}
