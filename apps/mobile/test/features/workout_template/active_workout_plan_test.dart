import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/demo/demo_templates.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/presentation/screens/active_workout_screen.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/domain/repositories/workout_template_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercises_repository.dart';
import '../../support/fake_workout_repository.dart';

/// Déroulé d'une séance issue d'un modèle : l'objectif de la série en cours
/// est affiché, la validation enregistre ce qui a RÉELLEMENT été fait, et
/// l'avancement dans le programme suit.
///
/// Une séance libre (sans modèle) doit garder exactement son comportement :
/// c'est le dernier test du fichier.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestWidgetsFlutterBinding
            .instance.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  /// Modèle « 4 × 8 à 60 kg » sur un seul exercice.
  const pushTemplate = SaveTemplateInput(
    id: 'tpl-1',
    name: 'Push — Force',
    exercises: [
      TemplateExerciseInput(
        exerciseName: 'Développé couché',
        sets: [
          PlannedSetInput(targetReps: 8, targetWeightKg: 60, restSeconds: 120),
          PlannedSetInput(targetReps: 8, targetWeightKg: 60, restSeconds: 120),
          PlannedSetInput(targetReps: 6, targetWeightKg: 70, restSeconds: 150),
        ],
      ),
    ],
  );

  /// Monte l'écran de séance active seul, sur une séance déjà lancée depuis
  /// [seed] quand il y en a un — sinon sur une séance libre.
  Future<(FakeWorkoutRepository, WorkoutTemplateRepository)> pumpActiveWorkout(
    WidgetTester tester, {
    SaveTemplateInput? seed,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final workouts = FakeWorkoutRepository();
    final templates = DemoWorkoutTemplateRepository(
      workouts,
      seed: seed == null ? const [] : [seed],
    );

    if (seed == null) {
      await workouts.startWorkout(name: 'Séance libre');
    } else {
      await templates.startFromTemplate(seed.id!);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(workouts),
          workoutTemplateRepositoryProvider.overrideWithValue(templates),
          exercisesRepositoryProvider.overrideWithValue(
            FakeExercisesRepository(
              [summary('id-1', 'Développé couché', group: 'pectoraux')],
              pageSize: 10,
            ),
          ),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ActiveWorkoutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (workouts, templates);
  }

  testWidgets('l’objectif de la série en cours est affiché', (tester) async {
    await pumpActiveWorkout(tester, seed: pushTemplate);

    // Provenance de la séance, puis consigne : « série 1 sur 3, 8 reps à 60 kg ».
    expect(find.text('Push — Force'), findsOneWidget);
    expect(find.text('SÉRIE 1 SUR 3 · DÉVELOPPÉ COUCHÉ'), findsOneWidget);
    expect(find.text('PRÉVU 8 × 60 KG'), findsOneWidget);

    // Le pas-à-pas est amorcé sur la cible, pas sur une valeur arbitraire.
    expect(find.text('60'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets(
      'valider une série : le réalisé est enregistré, le programme avance',
      (tester) async {
    final (workouts, templates) =
        await pumpActiveWorkout(tester, seed: pushTemplate);

    // Une répétition de moins que prévu : déviation NORMALE, jamais bloquée.
    await tester.tap(
      find.byTooltip('Diminuer : Répétitions'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider la série'));
    await tester.pumpAndSettle();

    // La série enregistre le réalisé, en conservant la cible affichée.
    expect(workouts.addedSets, hasLength(1));
    final recorded = workouts.addedSets.single;
    expect(recorded.reps, 7);
    expect(recorded.weightKg, 60);
    expect(recorded.plannedReps, 8);
    expect(recorded.plannedWeightKg, 60);
    // Le repos prescrit par le modèle prime sur le repos par défaut.
    expect(recorded.restSeconds, 120);

    // L'item de plan est honoré : faire 7 au lieu de 8 reste une série faite.
    final plan = await templates.sessionPlan(workouts.active!.session.id);
    expect(plan!.doneCount, 1);

    // Et l'écran affiche la consigne suivante.
    expect(find.text('SÉRIE 2 SUR 3 · DÉVELOPPÉ COUCHÉ'), findsOneWidget);
  });

  testWidgets('passer une série : rien n’est envoyé, le programme avance',
      (tester) async {
    final (workouts, templates) =
        await pumpActiveWorkout(tester, seed: pushTemplate);

    await tester.tap(find.text('Passer cette série'));
    await tester.pumpAndSettle();

    // Une série non faite n'est pas un fait : aucune écriture de série.
    expect(workouts.addedSets, isEmpty);

    final plan = await templates.sessionPlan(workouts.active!.session.id);
    expect(plan!.doneCount, 0);
    expect(plan.remainingCount, 2);

    // La cible suivante est bien celle de la deuxième série prévue.
    expect(find.text('SÉRIE 1 SUR 3 · DÉVELOPPÉ COUCHÉ'), findsOneWidget);
    expect(find.text('PRÉVU 8 × 60 KG'), findsOneWidget);
  });

  testWidgets('séance libre : aucun objectif, comportement inchangé',
      (tester) async {
    final (workouts, _) = await pumpActiveWorkout(tester);

    expect(find.textContaining('SUR'), findsNothing);
    expect(find.textContaining('PRÉVU'), findsNothing);
    expect(find.text('Passer cette série'), findsNothing);
    expect(find.text('Aucun exercice'), findsOneWidget);
    expect(workouts.active!.session.templateName, isNull);
  });
}
