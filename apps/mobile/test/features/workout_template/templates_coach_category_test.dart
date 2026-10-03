import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_template/domain/entities/workout_template.dart';
import 'package:carlys_mobile/features/workout_template/presentation/providers/workout_template_providers.dart';
import 'package:carlys_mobile/features/workout_template/presentation/screens/templates_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// « Mes modèles », catégorie Coach : toute séance proposée par le coach y
/// est gardée, et un onglet les isole.
void main() {
  WorkoutTemplateInfo modele(String id, String nom, {bool coach = false}) =>
      WorkoutTemplateInfo(
        id: id,
        name: nom,
        exercisesCount: 1,
        plannedSetsCount: 3,
        previewExerciseNames: const ['Squat'],
        updatedAt: DateTime.utc(2026, 10, 3),
        syncState: LocalSyncState.synced,
        fromCoach: coach,
      );

  Future<void> monter(WidgetTester tester, List<WorkoutTemplateInfo> list) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutTemplatesProvider.overrideWith((ref) => Stream.value(list)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const TemplatesScreen(),
        ),
      ),
    );
  }

  testWidgets('l’onglet Coach ne garde que les séances du coach', (
    tester,
  ) async {
    await monter(tester, [
      modele('a', 'Push A'),
      modele('b', 'Jambes du coach', coach: true),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Jambes du coach'), findsOneWidget);
    // La séance du coach porte sa pastille.
    expect(find.text('Coach'), findsNWidgets(2));

    await tester.tap(find.text('Coach').first);
    await tester.pumpAndSettle();

    expect(find.text('Push A'), findsNothing);
    expect(find.text('Jambes du coach'), findsOneWidget);
  });

  testWidgets('aucune séance du coach : pas d’onglet', (tester) async {
    await monter(tester, [modele('a', 'Push A')]);
    await tester.pumpAndSettle();

    expect(find.byType(AppSegmentedTabs), findsNothing);
  });
}
