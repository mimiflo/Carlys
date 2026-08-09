import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/muscle_group_card.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_exercises_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// La bibliothèque à deux étages.
///
/// Douze groupes en pastilles défilantes n'en montraient que trois. La grille
/// les montre tous — mais elle ajoute un étage, et un étage sans retour est
/// un cul-de-sac. C'est ce qui est vérifié ici.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Future<void> openLibrary(WidgetTester tester) async {
    // Écran de téléphone réel : sur la surface de test par défaut (800×600),
    // la seconde rangée de la grille passe sous la barre d'onglets flottante
    // et ne peut plus être touchée.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.development,
              apiBaseUrl: 'http://localhost:3000',
            ),
          ),
          authRepositoryProvider
              .overrideWithValue(FakeAuthRepository(storedSession: true)),
          exercisesRepositoryProvider.overrideWithValue(
            FakeExercisesRepository(
              [
                summary('id-1', 'Pompes', group: 'pectoraux'),
                summary('id-2', 'Squat', group: 'quadriceps'),
              ],
              pageSize: 10,
            ),
          ),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Exercices'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('l’onglet s’ouvre sur les groupes, pas sur la liste',
      (tester) async {
    await openLibrary(tester);

    // La grille se construit paresseusement : on vérifie ce qui est à
    // l'écran, pas un compte total.
    expect(find.byType(MuscleGroupCard), findsWidgets);
    expect(find.text('Tous les mouvements'), findsOneWidget);
    expect(find.text('Pectoraux'), findsOneWidget);
    // Aucun mouvement tant qu'on n'a pas choisi de terrain.
    expect(find.text('Pompes'), findsNothing);
  });

  testWidgets('choisir un groupe ouvre ses mouvements, et on peut revenir',
      (tester) async {
    await openLibrary(tester);

    await tester.tap(find.text('Pectoraux'));
    await tester.pumpAndSettle();

    expect(find.text('Pompes'), findsOneWidget);
    expect(find.byType(MuscleGroupCard), findsNothing);

    // Sans ce retour, l'étage du dessous serait un cul-de-sac : le seul
    // chemin vers les autres groupes serait de quitter l'onglet.
    await tester.tap(find.byTooltip('Revenir aux groupes musculaires'));
    await tester.pumpAndSettle();

    expect(find.byType(MuscleGroupCard), findsWidgets);
    expect(find.text('Pectoraux'), findsOneWidget);
  });

  testWidgets('« Tous les mouvements » ouvre le catalogue entier',
      (tester) async {
    await openLibrary(tester);

    await tester.tap(find.text('Tous les mouvements'));
    await tester.pumpAndSettle();

    expect(find.text('Pompes'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('chercher court-circuite les deux étages', (tester) async {
    await openLibrary(tester);

    // Chercher un nom ne suppose pas de savoir quel muscle il travaille.
    await tester.enterText(find.byType(TextField), 'Squat');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.byType(MuscleGroupCard), findsNothing);
    expect(find.text('Pompes'), findsNothing);
    // Pas de barre de retour : on n'est venu d'aucun groupe.
    expect(
      find.byTooltip('Revenir aux groupes musculaires'),
      findsNothing,
    );
  });

  testWidgets('un groupe sans détourage garde sa carte et son nom',
      (tester) async {
    await openLibrary(tester);

    // Les ischio-jambiers manquent à la planche fournie. La carte ne doit
    // surtout pas emprunter l'image d'un autre muscle.
    expect(MuscleGroupCard.assetFor('ischio-jambiers'), isNull);
    expect(MuscleGroupCard.assetFor('quadriceps'), isNotNull);

    await tester.scrollUntilVisible(
      find.text('Ischio-jambiers'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Ischio-jambiers'), findsOneWidget);
  });
}
