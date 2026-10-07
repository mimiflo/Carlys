import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/coaching/presentation/screens/coach_goal_screen.dart';
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

/// La page du coach : objectif, niveau, matériel — et RIEN d'autre, pas de
/// génération de programme. « C'est parti » ne s'allume qu'une fois tout
/// choisi, et rend `true` à qui l'a ouverte.
void main() {
  /// Ce que la page a rendu à qui l'a ouverte, une entrée par fermeture.
  final rendus = <bool?>[];

  Future<void> ouvrir(
    WidgetTester tester, {
    required TrainingProfile profil,
    TrainingGoal? objectif,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    rendus.clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingProfileRepositoryProvider.overrideWithValue(
            FakeTrainingProfileRepository(initial: profil),
          ),
          exercisesRepositoryProvider.overrideWithValue(
            FakeExercisesRepository(const [])
              ..equipmentRefs = const [
                EquipmentRef(id: 'e1', slug: 'halteres', name: 'Haltères'),
              ],
          ),
          currentTrainingGoalProvider.overrideWithValue(objectif),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => rendus.add(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CoachGoalScreen()),
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  const vide = TrainingProfile(
    goal: null,
    experience: null,
    weeklySessionsTarget: null,
    sessionMinutesTarget: null,
    equipmentSlugs: [],
  );

  testWidgets('rien de choisi : les trois questions, le bouton éteint', (
    tester,
  ) async {
    await ouvrir(tester, profil: vide);

    expect(find.text('Avant que je réfléchisse'), findsOneWidget);
    expect(find.text('TON OBJECTIF'), findsOneWidget);
    // Sous les huit objectifs : le niveau, puis le matériel.
    await tester.scrollUntilVisible(find.text('TON NIVEAU'), 300);
    expect(find.text('TON NIVEAU'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('TON MATÉRIEL'), 300);
    expect(find.text('TON MATÉRIEL'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Poids libres'), 300);
    expect(find.text('Rien de coché'), findsOneWidget);
    // Pas l'écran des programmes : ni rythme, ni génération.
    expect(find.textContaining('Générer'), findsNothing);
    expect(find.textContaining('par semaine'), findsNothing);
    final bouton = tester.widget<AppCtaButton>(find.byType(AppCtaButton));
    expect(bouton.onPressed, isNull);
    expect(bouton.label, 'Encore 3 réponses');
  });

  testWidgets('tout choisi : « C’est parti » referme et rend vrai', (
    tester,
  ) async {
    await ouvrir(
      tester,
      profil: const TrainingProfile(
        goal: TrainingGoal.hyrox,
        experience: TrainingExperience.beginner,
        weeklySessionsTarget: null,
        sessionMinutesTarget: null,
        equipmentSlugs: ['halteres'],
      ),
      objectif: TrainingGoal.hyrox,
    );

    await tester.tap(find.text('C’est parti'));
    await tester.pumpAndSettle();
    expect(find.text('Avant que je réfléchisse'), findsNothing);
    expect(rendus, [true]);
  });
}
