import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/presentation/providers/exercise_catalog_providers.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/exercise_picker_sheet.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/exercise_set_row.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/resume_workout_confirm.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/workout_close_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les popups de la séance EN COURS, passées des boîtes de dialogue Material
/// à la carte centrée du design system : supprimer une série, clore la
/// séance, reprendre celle qui tourne, saisir un exercice libre.
///
/// Ce qu'on protège : la réponse rendue à l'appelant, inchangée par la
/// migration — une question refusée (bouton, voile, retour) ne déclenche
/// RIEN.
void main() {
  late BuildContext screen;

  Widget app({Widget? body}) => ProviderScope(
    overrides: [
      // Le catalogue est vide : la feuille de choix propose l'exercice libre
      // sans attendre le réseau.
      exerciseSearchProvider.overrideWith(
        (ref, search) async => const <ExerciseSummary>[],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            screen = context;
            return body ?? const SizedBox.expand();
          },
        ),
      ),
    ),
  );

  /// Un bouton de la popup centrée, pas un texte homonyme de l'écran.
  Finder popupButton(String label) => find.descendant(
    of: find.byType(AppPopupCard),
    matching: find.widgetWithText(AppButton, label),
  );

  group('supprimer une série de la séance en cours', () {
    late int deletions;

    Future<void> mount(WidgetTester tester) async {
      deletions = 0;
      await tester.pumpWidget(
        app(
          body: ExerciseSetRow(
            position: 1,
            set: WorkoutSetEntry(
              id: 'serie',
              exerciseName: 'Squat',
              position: 0,
              kind: SetKind.normal,
              completedAt: DateTime.utc(2026, 9, 1, 17, 20),
              syncState: LocalSyncState.synced,
              reps: 5,
              weightKg: 100,
            ),
            onDelete: () async => deletions++,
          ),
        ),
      );
      await tester.longPress(find.byType(ExerciseSetRow));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppPopupCard, 'Supprimer la série ?'),
        findsOneWidget,
      );
    }

    testWidgets('confirmer supprime, par le bouton rouge', (tester) async {
      await mount(tester);
      expect(
        tester.widget<AppButton>(popupButton('Supprimer')).variant,
        AppButtonVariant.destructive,
      );

      await tester.tap(popupButton('Supprimer'));
      await tester.pumpAndSettle();

      expect(deletions, 1);
      expect(find.byType(AppPopupCard), findsNothing);
    });

    testWidgets('« Annuler » ne supprime rien', (tester) async {
      await mount(tester);
      await tester.tap(popupButton('Annuler'));
      await tester.pumpAndSettle();

      expect(deletions, 0);
      expect(find.byType(AppPopupCard), findsNothing);
    });

    testWidgets('toucher le voile ne supprime rien', (tester) async {
      await mount(tester);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      expect(deletions, 0);
      expect(find.byType(AppPopupCard), findsNothing);
    });

    testWidgets('le retour arrière ne supprime rien', (tester) async {
      await mount(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(deletions, 0);
      expect(find.byType(AppPopupCard), findsNothing);
    });
  });

  group('clore la séance', () {
    testWidgets('terminer : le constat du plan, puis « Confirmer » rend vrai', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final answer = showWorkoutCloseDialog(
        screen,
        abandon: false,
        planSummary: '9 séries sur 12 prévues',
      );
      await tester.pumpAndSettle();

      final card = find.byType(AppPopupCard);
      expect(
        find.descendant(of: card, matching: find.text('Terminer la séance ?')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.byType(AppPill)),
        findsOneWidget,
      );
      // Terminer clôt normalement : l'action principale, pas un danger.
      expect(
        tester.widget<AppButton>(popupButton('Confirmer')).variant,
        AppButtonVariant.primary,
      );

      await tester.tap(popupButton('Confirmer'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    testWidgets('le constat tient sur 320 points, texte agrandi deux fois', (
      tester,
    ) async {
      // Une pastille ne revenait pas à la ligne : à 320 points de large,
      // « 12 séries sur 12 prévues » débordait de la carte dès 1,3.
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(640, 1136);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(app());
      unawaited(
        showWorkoutCloseDialog(
          screen,
          abandon: false,
          planSummary: '12 séries sur 12 prévues',
        ),
      );
      await tester.pumpAndSettle();

      // Un débordement se signale comme une exception de rendu.
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(AppPopupCard));
      final summary = tester.getRect(find.byType(AppPill));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(320));
      expect(summary.left, greaterThanOrEqualTo(card.left));
      expect(summary.right, lessThanOrEqualTo(card.right));
    });

    testWidgets('abandonner : bouton rouge, « Annuler » rend faux', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final answer = showWorkoutCloseDialog(screen, abandon: true);
      await tester.pumpAndSettle();

      expect(find.text('Abandonner la séance ?'), findsOneWidget);
      expect(find.byType(AppPill), findsNothing);
      expect(
        tester.widget<AppButton>(popupButton('Confirmer')).variant,
        AppButtonVariant.destructive,
      );

      await tester.tap(popupButton('Annuler'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('toucher le voile ne confirme pas', (tester) async {
      await tester.pumpWidget(app());
      final answer = showWorkoutCloseDialog(screen, abandon: false);
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      // `null`, que l'appelant lit comme un refus (`confirmed != true`).
      expect(await answer, isNot(isTrue));
    });
  });

  group('une séance tourne déjà', () {
    testWidgets('« Reprendre la séance » rend vrai', (tester) async {
      await tester.pumpWidget(app());
      final answer = showResumeWorkoutConfirm(screen);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppPopupCard, 'Une séance est en cours'),
        findsOneWidget,
      );
      await tester.tap(popupButton('Reprendre la séance'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
    });

    testWidgets('« Plus tard » rend faux', (tester) async {
      await tester.pumpWidget(app());
      final answer = showResumeWorkoutConfirm(screen);
      await tester.pumpAndSettle();

      await tester.tap(popupButton('Plus tard'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });
  });

  group('exercice libre', () {
    Future<Future<PickedExercise?>> openFreeExercise(
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(app());
      final picked = showExercisePickerSheet(screen);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exercice libre (hors catalogue)'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppPopupCard, 'Exercice libre'),
        findsOneWidget,
      );
      return picked;
    }

    Finder field() => find.descendant(
      of: find.byType(AppPopupCard),
      matching: find.byType(TextField),
    );

    testWidgets('le nom saisi, sans ses espaces, devient l’exercice choisi', (
      tester,
    ) async {
      final picked = await openFreeExercise(tester);

      // Rien à choisir tant que le champ est vide.
      expect(
        tester.widget<AppButton>(popupButton('Choisir')).onPressed,
        isNull,
      );

      await tester.enterText(field(), '  Tirage poulie  ');
      await tester.pump();
      await tester.tap(popupButton('Choisir'));
      await tester.pumpAndSettle();

      final exercise = await picked;
      expect(exercise?.name, 'Tirage poulie');
      expect(exercise?.exerciseId, isNull);
      expect(find.text('Choisir un exercice'), findsNothing);
    });

    testWidgets('renoncer laisse la feuille ouverte, sans rien choisir', (
      tester,
    ) async {
      final picked = await openFreeExercise(tester);
      var settled = false;
      unawaited(picked.then((_) => settled = true));

      await tester.enterText(field(), 'Tirage poulie');
      await tester.pump();
      await tester.tap(popupButton('Annuler'));
      await tester.pumpAndSettle();

      expect(find.byType(AppPopupCard), findsNothing);
      expect(find.text('Choisir un exercice'), findsOneWidget);
      expect(settled, isFalse);
    });
  });
}
