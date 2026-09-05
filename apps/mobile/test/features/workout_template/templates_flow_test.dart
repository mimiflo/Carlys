import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/demo/demo_templates.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercises_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// Modèles de séance, côté interface : état vide, composition d'un modèle,
/// puis lancement d'une vraie séance pré-remplie.
void main() {
  setUp(() {
    // Parcours de première ouverture déjà terminé : l'application démarre
    // sur l'accueil.
    seedCompletedFirstRun();
    // La scène cœur de l'accueil boucle en continu : réduction d'animations
    // pour que pumpAndSettle converge.
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  /// Monte l'application avec des dépôts en mémoire, puis ouvre
  /// « Mes modèles » depuis l'accueil.
  Future<FakeWorkoutRepository> openTemplates(
    WidgetTester tester, {
    List<SaveTemplateInput> seed = const [],
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final workouts = FakeWorkoutRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.development,
              apiBaseUrl: 'http://localhost:3000',
            ),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedSession: true),
          ),
          exercisesRepositoryProvider.overrideWithValue(
            FakeExercisesRepository([
              summary('id-1', 'Développé couché', group: 'pectoraux'),
              summary('id-2', 'Squat', group: 'quadriceps'),
            ], pageSize: 10),
          ),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          nutritionRepositoryProvider.overrideWithValue(
            FakeNutritionRepository(),
          ),
          workoutRepositoryProvider.overrideWithValue(workouts),
          workoutTemplateRepositoryProvider.overrideWithValue(
            DemoWorkoutTemplateRepository(workouts, seed: seed),
          ),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();

    // La carte « séance du jour » est passée sous le résumé du jour, et
    // la liste est PARESSEUSE : il faut défiler jusqu'à elle pour
    // qu'elle existe.
    await tester.scrollUntilVisible(
      find.text('Lancer un modèle'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lancer un modèle'));
    await tester.pumpAndSettle();
    return workouts;
  }

  testWidgets('aucun modèle : l’état vide invite à composer sa séance type', (
    tester,
  ) async {
    await openTemplates(tester);

    expect(find.text('Mes modèles'), findsOneWidget);
    expect(find.text('Aucun modèle'), findsOneWidget);
    expect(
      find.text('Compose ta séance type une fois, relance-la en un geste.'),
      findsOneWidget,
    );
    expect(find.text('Créer un modèle'), findsOneWidget);
  });

  testWidgets('création : nommer, ajouter un exercice puis enregistrer', (
    tester,
  ) async {
    await openTemplates(tester);

    await tester.tap(find.text('Créer un modèle'));
    await tester.pumpAndSettle();

    // Éditeur vide : rien n'est enregistrable tant qu'il manque un nom ou un
    // exercice.
    expect(find.text('Nouveau modèle'), findsOneWidget);
    expect(find.text('AUCUN EXERCICE'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Push force'),
      'Push force',
    );
    await tester.pumpAndSettle();

    // L'exercice vient du catalogue existant, par le sélecteur de la séance.
    await tester.tap(find.text('Ajouter un exercice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Développé couché').last);
    await tester.pumpAndSettle();

    // La ligne s'ouvre sur sa première série prévue, réglable au pas-à-pas.
    expect(find.text('SÉRIE 1'), findsOneWidget);
    expect(find.text('1 EXERCICE · 1 SÉRIE PRÉVUE'), findsOneWidget);

    await tester.ensureVisible(find.text('Ajouter une série'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une série'));
    await tester.pumpAndSettle();
    expect(find.text('1 EXERCICE · 2 SÉRIES PRÉVUES'), findsOneWidget);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Retour à la liste : le modèle enregistré y figure avec ses faits.
    expect(find.text('Mes modèles'), findsOneWidget);
    expect(find.text('Push force'), findsOneWidget);
    expect(find.text('1 EXERCICE'), findsOneWidget);
    expect(find.text('2 SÉRIES'), findsOneWidget);
  });

  testWidgets('lancement : la séance démarre pré-remplie par le modèle', (
    tester,
  ) async {
    final workouts = await openTemplates(
      tester,
      seed: [
        const SaveTemplateInput(
          id: 'tpl-1',
          name: 'Push force',
          exercises: [
            TemplateExerciseInput(
              exerciseName: 'Développé couché',
              sets: [
                PlannedSetInput(
                  targetReps: 8,
                  targetWeightKg: 60,
                  restSeconds: 120,
                ),
                PlannedSetInput(
                  targetReps: 8,
                  targetWeightKg: 60,
                  restSeconds: 120,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    expect(find.text('Push force'), findsOneWidget);

    await tester.tap(find.text('Lancer'));
    await tester.pumpAndSettle();

    // Une vraie séance a démarré, avec la provenance du modèle.
    expect(workouts.active, isNotNull);
    expect(workouts.active!.session.templateName, 'Push force');
    expect(workouts.active!.session.templateId, 'tpl-1');

    // Et l'écran de séance active s'ouvre sur le programme.
    expect(find.text('Développé couché'), findsWidgets);
    expect(find.text('SÉRIE 1 SUR 2 · DÉVELOPPÉ COUCHÉ'), findsOneWidget);
  });
}

/// Le bouton « Enregistrer » de la barre basse de l'éditeur.
FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Enregistrer'),
);
