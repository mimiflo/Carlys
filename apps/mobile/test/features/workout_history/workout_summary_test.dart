import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_history/presentation/screens/workout_detail_screen.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';

/// Le bilan de séance (maquette d'octobre 2026) : les chiffres de la séance,
/// une carte par exercice, la première dépliée.
void main() {
  WorkoutSetEntry serie(int position, String name, int reps, double kg) =>
      WorkoutSetEntry(
        id: 's$position',
        exerciseName: name,
        position: position,
        kind: SetKind.normal,
        reps: reps,
        weightKg: kg,
        completedAt: DateTime.utc(2026, 10, 7, 18),
        syncState: LocalSyncState.synced,
      );

  Future<void> monter(WidgetTester tester, WorkoutWithSets seance) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(
            FakeWorkoutRepository()..active = seance,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: WorkoutDetailScreen(sessionId: seance.session.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final pushForce = WorkoutWithSets(
    session: WorkoutInfo(
      id: 'push',
      name: 'Push force',
      status: WorkoutStatus.completed,
      startedAt: DateTime.utc(2026, 10, 7, 17),
      durationSeconds: 48 * 60,
      syncState: LocalSyncState.synced,
    ),
    sets: [
      serie(1, 'Développé couché', 8, 80),
      serie(2, 'Développé couché', 8, 80),
      serie(3, 'Développé épaules', 10, 40),
    ],
  );

  testWidgets('les chiffres, et une carte par exercice', (tester) async {
    await monter(tester, pushForce);

    expect(find.text('Séance terminée !'), findsOneWidget);
    expect(find.text('Push force'), findsOneWidget);
    expect(find.text('48 min'), findsOneWidget);
    expect(find.text('${formatThousands(1680)} kg'), findsOneWidget);
    expect(find.text('2 exercices'), findsOneWidget);
    expect(find.text('2 séries • ${formatThousands(1280)} kg'), findsOneWidget);
  });

  testWidgets('la première carte est dépliée, les autres se déplient', (
    tester,
  ) async {
    await monter(tester, pushForce);

    // Dépliée : les lignes du tableau. Repliée : la série qui résume.
    expect(find.text('80 kg'), findsNWidgets(2));
    expect(find.text('40 kg × 10 reps'), findsOneWidget);
    expect(find.text('40 kg'), findsNothing);

    await tester.ensureVisible(find.text('Développé épaules'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Développé épaules'));
    await tester.pumpAndSettle();
    expect(find.text('40 kg'), findsOneWidget);
    expect(find.text('40 kg × 10 reps'), findsNothing);
  });

  testWidgets('une séance sans série le dit', (tester) async {
    await monter(
      tester,
      WorkoutWithSets(session: pushForce.session, sets: const []),
    );

    expect(find.text('Aucune série enregistrée'), findsOneWidget);
  });

  testWidgets(
    'supprimer la première série garde la carte dépliée, en correction',
    (tester) async {
      await monter(tester, pushForce);
      await tester.tap(find.byTooltip('Corriger'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('80 kg').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('80 kg'), findsOneWidget);
      expect(
        find.byTooltip('Terminer la correction'),
        findsOneWidget,
        reason: 'La carte ne doit pas se refermer sous le doigt.',
      );
    },
  );

  // Grand texte et petit écran : rien ne déborde, séance abandonnée comprise
  // (« Abandonnée », la pastille la plus longue).
  const cas = <(double, double)>[
    (393, 1),
    (360, 1.3),
    (393, 23 / 17),
    (320, 2),
  ];
  for (final (largeur, echelle) in cas) {
    testWidgets(
      '$largeur pt, texte ×${echelle.toStringAsFixed(2)} : rien ne déborde',
      (tester) async {
        tester.view.physicalSize = Size(largeur * 3, 852 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final abandonnee = WorkoutWithSets(
          session: WorkoutInfo(
            id: 'push',
            name: 'Push force',
            status: WorkoutStatus.abandoned,
            startedAt: DateTime.utc(2026, 10, 7, 17),
            durationSeconds: 48 * 60,
            syncState: LocalSyncState.synced,
          ),
          sets: [
            ...pushForce.sets,
            serie(4, 'Extension triceps à la poulie', 10, 25),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workoutRepositoryProvider.overrideWithValue(
                FakeWorkoutRepository()..active = abandonnee,
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(echelle)),
                child: child!,
              ),
              home: const WorkoutDetailScreen(sessionId: 'push'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Abandonnée'), findsOneWidget);
      },
    );
  }
}
