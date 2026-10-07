import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/data/repositories/exercises_repository_impl.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/training_profile_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_goal.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/training_profile.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/training_goal_providers.dart';
import 'package:carlys_mobile/features/workout_program/presentation/screens/training_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/contrast.dart';
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
    // Le matériel se range par famille, repliée : elle dit ce qui y est
    // coché, sans dérouler ses lignes.
    await voir(tester, 'Poids libres');
    expect(find.text('1 sur 2 · Barre'), findsOneWidget);
    expect(find.text('Haltères'), findsNothing);
  });

  testWidgets('choisir une expérience écrit SON champ, et lui seul', (
    tester,
  ) async {
    final repo = FakeTrainingProfileRepository();
    await monter(tester, repo: repo);

    // Le niveau se choisit dans sa feuille, ouverte depuis sa carte.
    await tester.tap(find.text('Choisir mon niveau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avancé'));
    await tester.pumpAndSettle();

    expect(repo.profile.experience, TrainingExperience.advanced);
    // Aucun autre champ n'a été touché par ce geste.
    expect(repo.profile.weeklySessionsTarget, isNull);
    expect(repo.equipmentWrites, isEmpty);
  });

  testWidgets('le rythme et la durée s’écrivent par tuiles', (tester) async {
    final repo = FakeTrainingProfileRepository();
    await monter(tester, repo: repo);

    await voir(tester, '4');
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(repo.profile.weeklySessionsTarget, 4);

    await voir(tester, '60 min');
    await tester.tap(find.text('60 min'));
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
      await voir(tester, 'Poids libres');
      await tester.tap(find.text('Poids libres'));
      await tester.pumpAndSettle();
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

  testWidgets('« Tout cocher » coche une famille entière en UNE écriture', (
    tester,
  ) async {
    final repo = FakeTrainingProfileRepository();
    await monter(tester, repo: repo);

    await voir(tester, 'Poids libres');
    await tester.tap(find.text('Poids libres'));
    await tester.pumpAndSettle();
    await voir(tester, 'Tout cocher');
    await tester.tap(find.text('Tout cocher'));
    await tester.pumpAndSettle();
    expect(repo.equipmentWrites.single.toSet(), {'barre', 'halteres'});
    expect(find.text('2 sur 2 · Barre, Haltères'), findsOneWidget);

    // Tout coché : la même ligne décoche la famille.
    await tester.tap(find.text('Tout décocher'));
    await tester.pumpAndSettle();
    expect(repo.equipmentWrites.last, isEmpty);
  });

  testWidgets('l’objectif reste modifiable : sa carte ouvre sa feuille', (
    tester,
  ) async {
    await monter(
      tester,
      repo: FakeTrainingProfileRepository(),
      goal: TrainingGoal.hyrox,
    );

    await tester.tap(find.text('Hyrox'));
    await tester.pumpAndSettle();
    expect(find.text('Ton objectif d’entraînement'), findsOneWidget);
  });

  testWidgets('fermer la feuille d’expérience sans choisir n’écrit rien', (
    tester,
  ) async {
    final repo = FakeTrainingProfileRepository();
    await monter(tester, repo: repo);

    await tester.tap(find.text('Choisir mon niveau'));
    await tester.pumpAndSettle();
    expect(find.text('Avancé'), findsOneWidget);
    // Un toucher hors de la feuille la ferme, sans réponse.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Avancé'), findsNothing);
    expect(repo.profile.experience, isNull);
  });

  testWidgets('à 320 points en texte doublé, chaque tuile reste à 48 points', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await monter(tester, repo: FakeTrainingProfileRepository());
    await voir(tester, '90 min');

    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets('la tuile choisie se lit sur son violet', (tester) async {
    await monter(
      tester,
      repo: FakeTrainingProfileRepository(
        initial: const TrainingProfile(
          goal: null,
          experience: null,
          weeklySessionsTarget: 4,
          sessionMinutesTarget: null,
          equipmentSlugs: [],
        ),
      ),
    );

    final tuile = surfacePainting(AppColors.cta);
    expect(tuile, findsOneWidget);
    expect(inkFailuresOn(tester, tuile), isEmpty);
  });

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
