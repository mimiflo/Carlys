import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/presentation/widgets/coach_training_frame.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/training_goal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercises_repository.dart';
import '../../support/fake_training_profile_repository.dart';

/// Le cadre du coach : objectif et matériel demandés d'emblée, rappelés
/// ensuite.
void main() {
  Future<void> monter(
    WidgetTester tester, {
    required TrainingProfile profile,
    TrainingGoal? goal,
  }) async {
    final exercises = FakeExercisesRepository(const [])
      ..equipmentRefs = const [
        EquipmentRef(id: 'e1', slug: 'barre', name: 'Barre'),
        EquipmentRef(id: 'e2', slug: 'halteres', name: 'Haltères'),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingProfileRepositoryProvider.overrideWithValue(
            FakeTrainingProfileRepository(initial: profile),
          ),
          exercisesRepositoryProvider.overrideWithValue(exercises),
          currentTrainingGoalProvider.overrideWithValue(goal),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: CoachTrainingFrame()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('rien de choisi : il demande ce qui manque, d’emblée', (
    tester,
  ) async {
    await monter(
      tester,
      profile: const TrainingProfile(
        goal: null,
        experience: TrainingExperience.beginner,
        weeklySessionsTarget: null,
        sessionMinutesTarget: null,
        equipmentSlugs: [],
      ),
    );

    expect(find.text('AVANT DE COMMENCER'), findsOneWidget);
    expect(find.textContaining('ton objectif et ton matériel'), findsOneWidget);
    expect(find.text('Choisir maintenant'), findsOneWidget);
  });

  testWidgets('tout choisi : une ligne le rappelle, qu’on peut modifier', (
    tester,
  ) async {
    await monter(
      tester,
      goal: TrainingGoal.fatLoss,
      profile: const TrainingProfile(
        goal: TrainingGoal.fatLoss,
        experience: TrainingExperience.beginner,
        weeklySessionsTarget: 3,
        sessionMinutesTarget: 45,
        equipmentSlugs: ['barre', 'halteres'],
      ),
    );

    expect(
      find.text('Objectif : Perte de gras · avec barre, haltères'),
      findsOneWidget,
    );
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('AVANT DE COMMENCER'), findsNothing);
  });
}
