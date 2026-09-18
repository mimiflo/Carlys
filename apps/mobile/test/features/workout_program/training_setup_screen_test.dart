import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/controllers/training_goal_controllers.dart';
import 'package:carlys_mobile/features/workout_program/presentation/screens/training_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_exercises_repository.dart';
import '../../support/fake_training_profile_repository.dart';

/// « Préparer mon programme » : l'écran reflète l'état serveur, chaque
/// geste écrit SON champ, et le matériel s'écrit toujours en liste
/// COMPLÈTE.
void main() {
  const barre = EquipmentRef(id: 'e1', slug: 'barre', name: 'Barre');
  const halteres = EquipmentRef(id: 'e2', slug: 'halteres', name: 'Haltères');

  Future<void> monter(
    WidgetTester tester, {
    required FakeTrainingProfileRepository repo,
    List<EquipmentRef> catalogue = const [barre, halteres],
    TrainingGoal? goal,
  }) async {
    final exercises = FakeExercisesRepository(const [])
      ..equipmentRefs = catalogue;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingProfileRepositoryProvider.overrideWithValue(repo),
          exercisesRepositoryProvider.overrideWithValue(exercises),
          currentTrainingGoalProvider.overrideWithValue(goal),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const TrainingSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// La page est une `ListView` paresseuse : on défile jusqu'à la cible
  /// avant de la chercher ou de la toucher.
  Future<void> voir(WidgetTester tester, String texte) async {
    await tester.scrollUntilVisible(
      find.text(texte),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reflète l’état serveur : sélections et matériel cochés', (
    tester,
  ) async {
    final repo = FakeTrainingProfileRepository(
      initial: const TrainingProfile(
        goal: null,
        experience: TrainingExperience.intermediate,
        weeklySessionsTarget: 4,
        sessionMinutesTarget: 60,
        equipmentSlugs: ['barre'],
      ),
    );
    await monter(tester, repo: repo, goal: TrainingGoal.hyrox);

    expect(find.text('Préparer mon programme'), findsOneWidget);
    // L'objectif du bandeau vient de la session, pas d'une copie.
    expect(find.text('Hyrox'), findsOneWidget);
    expect(find.text('Intermédiaire'), findsOneWidget);
    await voir(tester, 'Haltères');
    expect(find.text('Barre'), findsOneWidget);
    expect(find.text('Haltères'), findsOneWidget);
  });

  testWidgets('choisir une expérience écrit SON champ puis relit', (
    tester,
  ) async {
    final repo = FakeTrainingProfileRepository();
    await monter(tester, repo: repo);

    await voir(tester, 'Avancé');
    await tester.tap(find.text('Avancé'));
    await tester.pumpAndSettle();

    expect(repo.profile.experience, TrainingExperience.advanced);
    // Aucun autre champ n'a été touché par ce geste.
    expect(repo.profile.weeklySessionsTarget, isNull);
    expect(repo.equipmentWrites, isEmpty);
  });

  testWidgets('le rythme et la durée s’écrivent par pastilles', (tester) async {
    final repo = FakeTrainingProfileRepository();
    await monter(tester, repo: repo);

    await voir(tester, '4');
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(repo.profile.weeklySessionsTarget, 4);

    await voir(tester, '60 MIN');
    await tester.tap(find.text('60 MIN'));
    await tester.pumpAndSettle();
    expect(repo.profile.sessionMinutesTarget, 60);
  });

  testWidgets(
    'cocher et décocher le matériel envoie la liste COMPLÈTE à chaque fois',
    (tester) async {
      final repo = FakeTrainingProfileRepository(
        initial: const TrainingProfile(
          goal: null,
          experience: null,
          weeklySessionsTarget: null,
          sessionMinutesTarget: null,
          equipmentSlugs: ['barre'],
        ),
      );
      await monter(tester, repo: repo);

      // Ajouter les haltères : la liste envoyée porte les DEUX slugs.
      await voir(tester, 'Haltères');
      await tester.tap(find.text('Haltères'));
      await tester.pumpAndSettle();
      expect(repo.equipmentWrites.single.toSet(), {'barre', 'halteres'});

      // Retirer la barre : l'état suivant ne garde que les haltères.
      await tester.tap(find.text('Barre'));
      await tester.pumpAndSettle();
      expect(repo.equipmentWrites.last.toSet(), {'halteres'});
    },
  );

  testWidgets('la lecture en échec montre l’état d’erreur, réessayable', (
    tester,
  ) async {
    final repo = FakeTrainingProfileRepository()..failFetch = true;
    await monter(tester, repo: repo);

    expect(find.text('Préparation indisponible'), findsOneWidget);

    // Le réseau revient : « Réessayer » relit et l'écran se pose.
    repo.failFetch = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Préparer mon programme'), findsOneWidget);
  });
}
