import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_history/presentation/screens/workout_detail_screen.dart';
import 'package:carlys_mobile/features/workout_history/presentation/widgets/history_session_card.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';

/// Une séance en conflit de clôture offre un choix simple, là où
/// l'utilisateur voit ce qu'il tranche, et l'historique le signale.
void main() {
  WorkoutWithSets conflicting() => WorkoutWithSets(
    session: WorkoutInfo(
      id: 'fake-session',
      name: 'Push force',
      status: WorkoutStatus.completed,
      startedAt: DateTime.utc(2026, 9, 1, 17),
      durationSeconds: 3600,
      syncState: LocalSyncState.conflict,
    ),
    sets: const [],
  );

  Future<FakeWorkoutRepository> pumpDetail(WidgetTester tester) async {
    final repository = FakeWorkoutRepository()..active = conflicting();
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

  testWidgets('le détail propose les deux gestes', (tester) async {
    final repository = await pumpDetail(tester);

    expect(find.text('Conflit'), findsOneWidget);
    expect(
      find.text('Clôturée autrement sur un autre appareil'),
      findsOneWidget,
    );
    expect(find.text('Prendre la version du serveur'), findsOneWidget);
    expect(find.text('Garder ma version'), findsOneWidget);

    await tester.tap(find.text('Prendre la version du serveur'));
    await tester.pumpAndSettle();

    expect(repository.resolvedConflicts, [
      ('fake-session', WorkoutConflictResolution.takeServer),
    ]);
    // Tranché : la carte disparaît, la séance est synchronisée.
    expect(find.text('Garder ma version'), findsNothing);
    expect(find.text('Conflit'), findsNothing);
  });

  testWidgets('garder ma version passe par le même chemin', (tester) async {
    final repository = await pumpDetail(tester);

    await tester.tap(find.text('Garder ma version'));
    await tester.pumpAndSettle();

    expect(repository.resolvedConflicts, [
      ('fake-session', WorkoutConflictResolution.keepLocal),
    ]);
    expect(find.text('En attente'), findsOneWidget);
  });

  testWidgets('hors ligne : le message s’affiche, le choix reste', (
    tester,
  ) async {
    final repository = await pumpDetail(tester);
    repository.conflictResolutionFailure = const NetworkException(
      'Serveur injoignable',
    );

    await tester.tap(find.text('Prendre la version du serveur'));
    await tester.pumpAndSettle();

    expect(find.text('Serveur injoignable'), findsOneWidget);
    expect(find.text('Prendre la version du serveur'), findsOneWidget);
    expect(repository.resolvedConflicts, isEmpty);
  });

  testWidgets('une Error nue reste visible, le choix reste', (tester) async {
    // Sans source distante câblée, `takeServer` jette une `StateError` :
    // une `Error`, qu'un `on AppException` laissait passer. L'utilisateur
    // ne voyait alors rien, devant un bouton qui ne faisait rien.
    final repository = await pumpDetail(tester);
    repository.conflictResolutionFailure = StateError(
      'Aucune source distante : rien à rapatrier.',
    );

    await tester.tap(find.text('Prendre la version du serveur'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Impossible de trancher pour le moment'),
      findsOneWidget,
    );
    expect(find.text('Prendre la version du serveur'), findsOneWidget);
    expect(find.text('Garder ma version'), findsOneWidget);
    expect(repository.resolvedConflicts, isEmpty);
  });

  testWidgets('la carte annonce l’échec possible du rejeu', (tester) async {
    // L'API refuse aujourd'hui toute re-clôture avec une autre issue :
    // proposer « Garder ma version » sans le dire, c'est promettre un geste
    // qui ne peut pas aboutir.
    await pumpDetail(tester);

    expect(
      find.textContaining('Le serveur peut garder sa version'),
      findsOneWidget,
    );
    expect(
      find.textContaining('restera alors marquée en échec'),
      findsOneWidget,
    );
  });

  testWidgets('l’historique signale le conflit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: HistorySessionCard(
            entry: WorkoutHistoryEntry(
              session: conflicting().session,
              setsCount: 12,
              totalVolumeKg: 2400,
            ),
            hasRecord: false,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Conflit de synchronisation, à trancher',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.error), findsOneWidget);
  });
}
