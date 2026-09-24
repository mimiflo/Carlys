import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/presentation/widgets/template_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Supprimer un modèle par l'appui long sur sa carte : la question est la
/// popup centrée du design system (`showAppConfirm`, bouton rouge), et un
/// refus, par quelque porte qu'on sorte, ne supprime RIEN.
void main() {
  late int deletions;

  Future<void> mount(WidgetTester tester) async {
    deletions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ListView(
            children: [
              TemplateCard(
                template: WorkoutTemplateInfo(
                  id: 'modele',
                  name: 'Push force',
                  exercisesCount: 3,
                  plannedSetsCount: 9,
                  previewExerciseNames: const ['Développé couché'],
                  updatedAt: DateTime.utc(2026, 9, 1),
                  syncState: LocalSyncState.synced,
                ),
                onOpen: () {},
                onStart: () {},
                onDelete: () => deletions++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Push force'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppPopupCard, 'Supprimer « Push force » ?'),
      findsOneWidget,
    );
  }

  Finder popupButton(String label) => find.descendant(
    of: find.byType(AppPopupCard),
    matching: find.widgetWithText(AppButton, label),
  );

  testWidgets('confirmer supprime, par le bouton rouge', (tester) async {
    await mount(tester);
    expect(
      tester.widget<AppButton>(popupButton('Supprimer')).variant,
      AppButtonVariant.destructive,
    );

    await tester.tap(popupButton('Supprimer'));
    await tester.pumpAndSettle();

    expect(deletions, 1);
  });

  testWidgets('« Annuler » ne supprime rien', (tester) async {
    await mount(tester);
    await tester.tap(popupButton('Annuler'));
    await tester.pumpAndSettle();

    expect(deletions, 0);
    expect(find.byType(AppPopupCard), findsNothing);
  });

  testWidgets('le voile et le retour arrière ne suppriment rien', (
    tester,
  ) async {
    await mount(tester);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(AppPopupCard), findsNothing);

    await tester.longPress(find.text('Push force'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AppPopupCard), findsNothing);
    expect(deletions, 0);
  });
}
