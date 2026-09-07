import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_history/presentation/screens/workout_detail_screen.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';

/// Une séance mise de côté par la synchronisation avait un seul rejeu : la
/// prochaine ouverture de l'application. Dans une session donnée,
/// l'utilisateur voyait l'échec sans pouvoir rien en faire — il fallait tuer
/// et relancer l'application. Le détail de la séance offre le geste.
void main() {
  WorkoutWithSets stalled(LocalSyncState state) => WorkoutWithSets(
    session: WorkoutInfo(
      id: 'fake-session',
      name: 'Push force',
      status: WorkoutStatus.completed,
      startedAt: DateTime.utc(2026, 9, 1, 17),
      durationSeconds: 3600,
      syncState: state,
    ),
    sets: const [],
  );

  Future<FakeWorkoutRepository> pumpDetail(
    WidgetTester tester, {
    LocalSyncState state = LocalSyncState.failed,
  }) async {
    final repository = FakeWorkoutRepository()..active = stalled(state);
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

  testWidgets('une séance en échec offre le rejeu, et il repart', (
    tester,
  ) async {
    final repository = await pumpDetail(tester);

    expect(find.text('Pas encore envoyée au serveur'), findsOneWidget);
    expect(find.textContaining('Rien n’est perdu'), findsOneWidget);

    await tester.tap(find.text('Réessayer la synchronisation'));
    await tester.pumpAndSettle();

    expect(repository.retryFailedSyncCalls, 1);
    // Reparti : la séance n'est plus en échec, la carte disparaît.
    expect(find.text('Pas encore envoyée au serveur'), findsNothing);
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('hors ligne : le message s’affiche, le geste reste', (
    tester,
  ) async {
    final repository = await pumpDetail(tester);
    repository.retryFailedSyncFailure = const NetworkException(
      'Serveur injoignable',
    );

    await tester.tap(find.text('Réessayer la synchronisation'));
    await tester.pumpAndSettle();

    expect(find.text('Serveur injoignable'), findsOneWidget);
    expect(find.text('Réessayer la synchronisation'), findsOneWidget);
  });

  testWidgets('une Error nue reste visible, pas silencieuse', (tester) async {
    // Une base fermée sous le rejeu signale par une `Error` : l'écran ne doit
    // pas rester bloqué en chargement sans rien dire.
    final repository = await pumpDetail(tester);
    repository.retryFailedSyncFailure = StateError('base fermée');

    await tester.tap(find.text('Réessayer la synchronisation'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Impossible de réessayer pour le moment'),
      findsOneWidget,
    );
    expect(find.text('Réessayer la synchronisation'), findsOneWidget);
  });

  testWidgets('une séance synchronisée ne propose rien', (tester) async {
    await pumpDetail(tester, state: LocalSyncState.synced);

    expect(find.text('Réessayer la synchronisation'), findsNothing);
  });
}
