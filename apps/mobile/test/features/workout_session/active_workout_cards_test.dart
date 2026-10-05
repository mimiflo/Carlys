import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:carlys_mobile/features/workout_session/presentation/controllers/workout_controllers.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/current_exercise_card.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/exercise_sets_table.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/rest_timer_row.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/set_entry_card.dart';
import 'package:carlys_mobile/features/workout_session/presentation/widgets/set_entry_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les cartes de la séance en cours : ce qu'elles DISENT de l'avancement.
void main() {
  WorkoutSetEntry serie(String id, {double? kg, int? reps, int? seconds}) =>
      WorkoutSetEntry(
        id: id,
        exerciseName: 'Développé couché',
        position: 0,
        kind: SetKind.normal,
        completedAt: DateTime.utc(2026, 10, 5, 17),
        syncState: LocalSyncState.synced,
        weightKg: kg,
        reps: reps,
        durationSeconds: seconds,
      );

  // Ce que la ligne annonce au lecteur d'écran (son `Semantics` exclut ses
  // textes : c'est ce libellé, et lui seul, qui est lu).
  Finder annonce(String label) => find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  );

  Future<void> monter(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('les phrases de la carte de série', () {
    test('l’objectif suit ce que le programme prévoit, au singulier près', () {
      expect(
        setObjectiveLabel(reps: 8, weightKg: 80),
        'Objectif : 8 répétitions à 80 kg',
      );
      expect(setObjectiveLabel(reps: 1), 'Objectif : 1 répétition');
      expect(setObjectiveLabel(weightKg: 62.5), 'Objectif : 62,5 kg');
      expect(setObjectiveLabel(), isNull);
    });

    test('la dernière série se dit dans son unité', () {
      expect(
        previousSetLabel(serie('a', kg: 80, reps: 8)),
        'Dernière série : 80 kg × 8 reps',
      );
      expect(previousSetLabel(null), isNull);
      // Un gainage n'a ni charge ni répétitions : il ne se montre pas en
      // « — kg × — ».
      expect(previousSetLabel(serie('b', seconds: 45)), contains('45'));
    });
  });

  testWidgets('le rang suit le PROGRAMME : une série passée le fait avancer', (
    tester,
  ) async {
    // Une série faite, une passée : le programme propose la troisième.
    await monter(
      tester,
      const CurrentExerciseCard(
        name: 'Développé couché',
        doneSets: 1,
        upcomingSets: 1,
        setRank: 3,
        setsInExercise: 4,
      ),
    );
    expect(find.text('Série 3 sur 4'), findsOneWidget);

    // Sans programme : le rang de la prochaine saisie, sans total inventé.
    await monter(
      tester,
      const CurrentExerciseCard(
        name: 'Développé couché',
        doneSets: 2,
        upcomingSets: 0,
      ),
    );
    expect(find.text('Série 3'), findsOneWidget);
  });

  testWidgets('le tableau compte les validées et montre la cible en cours', (
    tester,
  ) async {
    await monter(
      tester,
      ExerciseSetsTable(
        sets: [serie('a', kg: 80, reps: 8), serie('b', kg: 80, reps: 8)],
        upcomingSets: 1,
        timeMode: false,
        plannedWeightKg: 82.5,
        plannedReps: 6,
        setRank: 3,
        setsInExercise: 4,
        onDelete: (_) async {},
      ),
    );
    expect(find.text('2 / 4 validées'), findsOneWidget);
    expect(
      annonce('Série 3 à saisir, cible 82,5 kg × 6 répétitions'),
      findsOneWidget,
    );
    expect(find.text('À saisir'), findsOneWidget);
    expect(find.text('À venir'), findsOneWidget);
    // La ligne en cours porte la cible du programme, pas des tirets.
    expect(find.text('82,5'), findsOneWidget);

    // Une série PASSÉE : le programme propose la troisième, et le tableau
    // le dit comme les cartes au-dessus. Sur la dernière série prévue, le
    // total reste celui du programme.
    await monter(
      tester,
      ExerciseSetsTable(
        sets: [serie('a', kg: 80, reps: 8)],
        upcomingSets: 0,
        timeMode: false,
        setRank: 3,
        setsInExercise: 3,
        onDelete: (_) async {},
      ),
    );
    expect(find.text('1 / 3 validées'), findsOneWidget);
    expect(annonce('Série 3 à saisir'), findsOneWidget);

    // Séance libre : rien n'est prévu, on compte ce qui est fait.
    await monter(
      tester,
      ExerciseSetsTable(
        sets: [serie('a', kg: 80, reps: 8)],
        upcomingSets: 0,
        timeMode: false,
        onDelete: (_) async {},
      ),
    );
    expect(find.text('1 validée'), findsOneWidget);
    expect(find.text('À venir'), findsNothing);
  });

  // Le plus petit téléphone, texte système doublé : la saisie et le repos
  // tiennent sans déborder. Deux disques de 48 points côte à côte, une
  // charge de six caractères et un décompte en 34 points, c'est là qu'ils
  // cassaient à la relecture.
  testWidgets('la saisie et le repos tiennent sur 320 points, texte ×2', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  SetEntryCard(
                    setNumber: 3,
                    previous: serie('a', kg: 102.5, reps: 8),
                    onValidate: (_) {},
                    onSkipSet: () {},
                    onSkipExercise: () {},
                  ),
                  RestTimerRow(
                    timer: const RestTimerState(
                      total: Duration(seconds: 90),
                      remaining: Duration(seconds: 75),
                    ),
                    onSkip: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
