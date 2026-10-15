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
    FakeTrainingProfileRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    rendus.clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingProfileRepositoryProvider.overrideWithValue(
            repository ?? FakeTrainingProfileRepository(initial: profil),
          ),
          exercisesRepositoryProvider.overrideWithValue(
            FakeExercisesRepository(const [])
              ..equipmentRefs = const [
                EquipmentRef(
                  id: 'e0',
                  slug: 'poids-du-corps',
                  name: 'Poids du corps',
                ),
                EquipmentRef(id: 'e1', slug: 'halteres', name: 'Haltères'),
                EquipmentRef(id: 'e2', slug: 'poulie', name: 'Poulie'),
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
    // Le matériel se demande globalement : un lieu, pas une liste.
    await tester.scrollUntilVisible(find.text('OÙ TU T’ENTRAÎNES'), 300);
    await tester.scrollUntilVisible(find.text('Sans matériel'), 300);
    expect(find.text('Salle de sport'), findsOneWidget);
    expect(find.text('À la maison'), findsOneWidget);
    expect(find.text('Poids libres'), findsNothing);
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

  testWidgets('« Salle de sport » écrit tout le matériel du catalogue', (
    tester,
  ) async {
    final profils = FakeTrainingProfileRepository(initial: vide);
    await ouvrir(tester, profil: vide, repository: profils);

    await tester.scrollUntilVisible(find.text('Salle de sport'), 300);
    await tester.tap(find.text('Salle de sport'));
    await tester.pumpAndSettle();

    expect(profils.equipmentWrites.last, [
      'poids-du-corps',
      'halteres',
      'poulie',
    ]);
    // Le lieu choisi se voit coché.
    expect(
      tester
          .widget<AppChoiceCard>(
            find.ancestor(
              of: find.text('Salle de sport'),
              matching: find.byType(AppChoiceCard),
            ),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('matériel réglé au détail ailleurs : signalé, aucun lieu coché', (
    tester,
  ) async {
    await ouvrir(
      tester,
      profil: const TrainingProfile(
        goal: null,
        experience: null,
        weeklySessionsTarget: null,
        sessionMinutesTarget: null,
        equipmentSlugs: ['poulie'],
      ),
    );

    await tester.scrollUntilVisible(
      find.textContaining('réglé au détail'),
      300,
    );
    expect(find.textContaining('réglé au détail'), findsOneWidget);
    expect(
      tester
          .widgetList<AppChoiceCard>(find.byType(AppChoiceCard))
          .where((card) => card.selected),
      isEmpty,
    );
  });
}
