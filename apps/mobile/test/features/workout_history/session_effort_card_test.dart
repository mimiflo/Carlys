import 'dart:ui' show Tristate;

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/workout_history/presentation/screens/workout_detail_screen.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercises_repository.dart';
import '../../support/fake_workout_repository.dart';

/// Le catalogue hors ligne : les fiches de [offline] ne répondent pas
/// (toutes, par défaut).
class _OfflineCatalog extends FakeExercisesRepository {
  _OfflineCatalog({this.offline})
    : super([
        summary('dc', 'Développé couché', group: 'Pectoraux'),
        summary('tri', 'Extension triceps', group: 'Triceps'),
      ]);

  final Set<String>? offline;

  @override
  Future<ExerciseDetail> byIdOrSlug(String idOrSlug) async {
    if (offline == null || offline!.contains(idOrSlug)) {
      throw const NetworkException('Hors ligne');
    }
    return super.byIdOrSlug(idOrSlug);
  }
}

/// « Comment c'était ? » sur le bilan : cinq réponses, facultatives,
/// modifiables, et le repos conseillé une fois l'effort donné.
void main() {
  // Close il y a une heure : l'échéance du repos est à venir.
  final endedAt = DateTime.now().toUtc().subtract(const Duration(hours: 1));

  WorkoutSetEntry serie(int position, String exerciseId, String name) =>
      WorkoutSetEntry(
        id: 's$position',
        exerciseId: exerciseId,
        exerciseName: name,
        position: position,
        kind: SetKind.normal,
        reps: 8,
        weightKg: 60,
        completedAt: endedAt,
        syncState: LocalSyncState.synced,
      );

  WorkoutWithSets push({
    int? effort,
    WorkoutStatus status = WorkoutStatus.completed,
  }) => WorkoutWithSets(
    session: WorkoutInfo(
      id: 'push',
      name: 'Push force',
      status: status,
      startedAt: endedAt.subtract(const Duration(minutes: 48)),
      endedAt: endedAt,
      durationSeconds: 48 * 60,
      syncState: LocalSyncState.synced,
      perceivedEffort: effort,
    ),
    sets: [
      serie(1, 'dc', 'Développé couché'),
      serie(2, 'tri', 'Extension triceps'),
    ],
  );

  final catalog = FakeExercisesRepository([
    summary('dc', 'Développé couché', group: 'Pectoraux'),
    summary('tri', 'Extension triceps', group: 'Triceps'),
  ]);

  Future<FakeWorkoutRepository> monter(
    WidgetTester tester,
    WorkoutWithSets seance, {
    FakeExercisesRepository? exercises,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final workouts = FakeWorkoutRepository()..active = seance;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider.overrideWithValue(workouts),
          exercisesRepositoryProvider.overrideWithValue(exercises ?? catalog),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: WorkoutDetailScreen(sessionId: seance.session.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // En bas du bilan, après le détail des exercices : la liste ne construit
    // pas ce qu'on ne voit pas.
    await tester.scrollUntilVisible(
      find.text('Retour à l’entraînement'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    return workouts;
  }

  testWidgets('sans effort choisi : les cinq réponses, aucun repos', (
    tester,
  ) async {
    await monter(tester, push());

    for (final label in [
      'Très facile',
      'Facile',
      'Modéré',
      'Difficile',
      'À fond',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Repos conseillé'), findsNothing);
  });

  testWidgets('choisir, puis le repos conseillé avec les muscles', (
    tester,
  ) async {
    final workouts = await monter(tester, push());

    await tester.tap(find.text('Difficile'));
    await tester.pumpAndSettle();

    expect(workouts.ratedEfforts, [('push', 7)]);
    expect(
      find.textContaining(
        'Repos conseillé : 72 h pour pectoraux et triceps, jusqu’à ',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('pas un avis médical'), findsOneWidget);
  });

  testWidgets('toucher la réponse choisie la retire', (tester) async {
    final workouts = await monter(tester, push(effort: 5));
    expect(find.textContaining('Repos conseillé : 48 h'), findsOneWidget);

    await tester.tap(find.text('Modéré'));
    await tester.pumpAndSettle();

    expect(workouts.ratedEfforts, [('push', null)]);
    expect(find.textContaining('Repos conseillé'), findsNothing);
  });

  testWidgets('une panne de la base locale se voit, jamais en silence', (
    tester,
  ) async {
    final workouts = await monter(tester, push());
    // Une base fermée signale par une `Error`, pas une `AppException`.
    workouts.effortFailure = StateError('base fermée');

    await tester.tap(find.text('Difficile'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Impossible d’enregistrer pour le moment'),
      findsOneWidget,
    );
  });

  testWidgets('hors ligne : le repos se dit sans muscles, sans erreur', (
    tester,
  ) async {
    await monter(tester, push(effort: 2), exercises: _OfflineCatalog());

    expect(
      find.textContaining('Repos conseillé : 24 h, jusqu’à '),
      findsOneWidget,
    );
  });

  testWidgets('une fiche sur deux illisible : la durée seule, jamais une '
      'liste de muscles tronquée', (tester) async {
    await monter(
      tester,
      push(effort: 7),
      exercises: _OfflineCatalog(offline: {'tri'}),
    );

    expect(
      find.textContaining('Repos conseillé : 72 h, jusqu’à '),
      findsOneWidget,
    );
    expect(find.textContaining('pectoraux'), findsNothing);
  });

  testWidgets('séance abandonnée : ni « Comment c’était ? » ni repos', (
    tester,
  ) async {
    await monter(tester, push(effort: 7, status: WorkoutStatus.abandoned));

    expect(find.text('Comment c’était ?'), findsNothing);
    expect(find.textContaining('Repos conseillé'), findsNothing);
  });

  testWidgets('accessible : choix exclusifs annoncés, cibles tactiles', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await monter(tester, push(effort: 7));

    final choisi = tester.getSemantics(find.text('Difficile'));
    expect(choisi.flagsCollection.isSelected, Tristate.isTrue);
    expect(choisi.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    expect(choisi.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    final autre = tester.getSemantics(find.text('Facile'));
    expect(autre.flagsCollection.isSelected, Tristate.isFalse);

    for (final label in ['Très facile', 'À fond']) {
      final size = tester.getSize(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(AppSpacing.touchTarget));
      expect(size.width, greaterThanOrEqualTo(AppSpacing.touchTarget));
    }
    semantics.dispose();
  });
}
