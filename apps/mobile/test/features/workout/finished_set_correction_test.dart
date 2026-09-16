import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_history/presentation/screens/workout_detail_screen.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';

/// Une séance TERMINÉE était définitivement figée : aucun écran n'offrait de
/// corriger une série ni d'en supprimer une. Or les records se recalculent à
/// partir de ces séries, donc une charge saisie 200 au lieu de 20 posait un
/// record faux et définitif.
void main() {
  const setId = 'set-fautif';

  WorkoutWithSets terminee({int reps = 5, double weightKg = 200}) =>
      WorkoutWithSets(
        session: WorkoutInfo(
          id: 'fake-session',
          name: 'Jambes',
          status: WorkoutStatus.completed,
          startedAt: DateTime.utc(2026, 9, 1, 17),
          durationSeconds: 3600,
          syncState: LocalSyncState.synced,
        ),
        sets: [
          WorkoutSetEntry(
            id: setId,
            exerciseName: 'Squat',
            position: 0,
            kind: SetKind.normal,
            completedAt: DateTime.utc(2026, 9, 1, 17, 20),
            syncState: LocalSyncState.synced,
            reps: reps,
            weightKg: weightKg,
          ),
        ],
      );

  Future<FakeWorkoutRepository> monter(WidgetTester tester) async {
    final repository = FakeWorkoutRepository()..active = terminee();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workoutRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WorkoutDetailScreen(sessionId: 'fake-session'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('la série s’ouvre en correction, et la valeur change', (
    tester,
  ) async {
    final repository = await monter(tester);
    expect(find.text('5 × 200 kg'), findsOneWidget);

    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
    expect(find.text('Corriger la série'), findsOneWidget);

    // La feuille s'ouvre PRÉ-REMPLIE : on corrige une valeur, on ne la
    // ressaisit pas de zéro.
    final charge = find.widgetWithText(AppTextField, 'Charge (kg)');
    expect(tester.widget<AppTextField>(charge).controller?.text, '200');

    await tester.enterText(charge, '20');
    await tester.tap(find.widgetWithText(AppButton, 'Corriger'));
    await tester.pumpAndSettle();

    expect(repository.active!.sets.single.weightKg, 20);
    expect(
      repository.active!.sets.single.reps,
      5,
      reason: 'Le champ non touché ne doit pas être réécrit.',
    );
  });

  testWidgets('la feuille dit que le record va être recalculé', (tester) async {
    await monter(tester);
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    // Personne ne devine qu'un record peut DESCENDRE : la conséquence se dit
    // avant le geste, comme pour la suppression d'une mesure corporelle.
    expect(
      find.textContaining('records', findRichText: true),
      findsWidgets,
      reason: 'La feuille doit annoncer le recalcul des records.',
    );
  });

  testWidgets('une correction annulée n’écrit rien', (tester) async {
    final repository = await monter(tester);
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();

    // Fermer la feuille sans valider.
    Navigator.of(tester.element(find.text('Corriger la série'))).pop();
    await tester.pumpAndSettle();

    expect(repository.active!.sets.single.weightKg, 200);
  });

  testWidgets('un appui long supprime, après confirmation qui dit l’effet', (
    tester,
  ) async {
    final repository = await monter(tester);

    await tester.longPress(find.text('Squat'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer cette série ?'), findsOneWidget);
    expect(find.textContaining('recalculés'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(repository.active!.sets, isEmpty);
  });

  testWidgets('une suppression refusée laisse la série en place', (
    tester,
  ) async {
    final repository = await monter(tester);

    await tester.longPress(find.text('Squat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
    await tester.pumpAndSettle();

    expect(repository.active!.sets, hasLength(1));
  });

  testWidgets('la ligne annonce sa valeur AVANT de proposer la correction', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await monter(tester);

    // La donnée d'abord, le geste ensuite : le lecteur d'écran donne le fait
    // avant d'annoncer ce qu'on peut en faire.
    expect(
      tester.getSemantics(find.text('Squat')).label,
      'Squat, 5 répétitions, 200 kilos. Corriger',
    );

    handle.dispose();
  });
}
