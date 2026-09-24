import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/water_controllers.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/program_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_program_repository.dart';
import '../../support/fake_water_store.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/in_memory_workout_template_repository.dart';
import '../../support/navigation.dart';

/// Les programmes multi-semaines dans l'application : liste, création,
/// calendrier éditable, programme suivi, suppression.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Future<void> pumpApp(
    WidgetTester tester,
    FakeProgramRepository programs,
  ) async {
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
          workoutRepositoryProvider.overrideWithValue(workouts),
          // Les modèles de la feuille d'affectation (Push force, Pull,
          // Hypertrophie) viennent du seed de démonstration.
          workoutTemplateRepositoryProvider.overrideWithValue(
            InMemoryWorkoutTemplateRepository(workouts),
          ),
          programRepositoryProvider.overrideWithValue(programs),
          waterStoreProvider.overrideWithValue(FakeWaterStore()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPrograms(WidgetTester tester) async {
    await tapTab(tester, 'Training');
    await tester.tap(find.text('Programmes'));
    await tester.pumpAndSettle();
  }

  ProgramDetail programOf({bool isActive = false}) => ProgramDetail(
    id: 'programme-1',
    name: 'Force en 2 semaines',
    weeksCount: 2,
    isActive: isActive,
    days: const [
      ProgramDayEntry(
        id: 'jour-1',
        weekNumber: 1,
        dayOfWeek: 2,
        label: 'Repos',
        isRest: true,
      ),
    ],
  );

  testWidgets('créer un programme ouvre son calendrier vide', (tester) async {
    final programs = FakeProgramRepository();
    await pumpApp(tester, programs);
    await openPrograms(tester);

    expect(find.text('Aucun programme'), findsOneWidget);

    await tester.tap(find.text('Créer un programme'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Force en 2 semaines');
    await tester.enterText(fields.at(1), '2');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    // Le calendrier : deux semaines, quatorze cases à planifier.
    expect(find.text('SEMAINE 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SEMAINE 2'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(programs.saveCount, 1);
  });

  testWidgets('affecter un jour : repos depuis la feuille', (tester) async {
    final programs = FakeProgramRepository(programs: [programOf()]);
    await pumpApp(tester, programs);
    await openPrograms(tester);

    await tester.tap(find.text('Force en 2 semaines'));
    await tester.pumpAndSettle();

    // LUN de la semaine 1 est vide : la feuille propose repos et modèles.
    await tester.tap(find.text('À planifier').first);
    await tester.pumpAndSettle();
    expect(find.text('Push force'), findsOneWidget);

    await tester.tap(find.text('Repos').last);
    await tester.pumpAndSettle();

    final saved = await programs.byId('programme-1');
    expect(saved.dayAt(1, 1)?.isRest, isTrue);
    expect(find.text('Repos'), findsNWidgets(2));
  });

  testWidgets('affecter un modèle : le nom du modèle remplit la case', (
    tester,
  ) async {
    final programs = FakeProgramRepository(programs: [programOf()]);
    await pumpApp(tester, programs);
    await openPrograms(tester);

    await tester.tap(find.text('Force en 2 semaines'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('À planifier').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Push force'));
    await tester.pumpAndSettle();

    final saved = await programs.byId('programme-1');
    expect(saved.dayAt(1, 1)?.templateId, isNotNull);
    expect(saved.dayAt(1, 1)?.label, 'Push force');
    expect(find.text('Push force'), findsOneWidget);
  });

  testWidgets('« Programme suivi » écrit l’activation ; badge sur la liste', (
    tester,
  ) async {
    final programs = FakeProgramRepository(programs: [programOf()]);
    await pumpApp(tester, programs);
    await openPrograms(tester);

    expect(find.text('SUIVI'), findsNothing);
    await tester.tap(find.text('Force en 2 semaines'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect((await programs.byId('programme-1')).isActive, isTrue);

    // Retour à la liste (geste système : l'app n'a pas de chrome de retour).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('SUIVI'), findsOneWidget);
  });

  testWidgets('supprimer ramène à une liste vide', (tester) async {
    final programs = FakeProgramRepository(programs: [programOf()]);
    await pumpApp(tester, programs);
    await openPrograms(tester);

    await tester.tap(find.text('Force en 2 semaines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer le programme'));
    await tester.pumpAndSettle();
    await tester.tap(_popupButton('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun programme'), findsOneWidget);
  });

  testWidgets('renoncer à la suppression ne supprime rien', (tester) async {
    final programs = FakeProgramRepository(programs: [programOf()]);
    await pumpApp(tester, programs);
    await openPrograms(tester);

    await tester.tap(find.text('Force en 2 semaines'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Supprimer le programme'));
    await tester.pumpAndSettle();

    // La question est la popup centrée, et son bouton dit le danger.
    expect(find.text('Supprimer ce programme ?'), findsOneWidget);
    expect(
      tester.widget<AppButton>(_popupButton('Supprimer')).variant,
      AppButtonVariant.destructive,
    );
    await tester.tap(_popupButton('Annuler'));
    await tester.pumpAndSettle();

    // L'écran reste (on ne quitte que sur une suppression aboutie), et la
    // liste le montre toujours au retour.
    expect(find.text('Supprimer ce programme ?'), findsNothing);
    expect(find.byTooltip('Supprimer le programme'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Force en 2 semaines'), findsOneWidget);
    expect(find.text('Aucun programme'), findsNothing);
  });
}

/// Un bouton de la popup centrée, pas un texte homonyme de l'écran.
Finder _popupButton(String label) => find.descendant(
  of: find.byType(AppPopupCard),
  matching: find.widgetWithText(AppButton, label),
);
