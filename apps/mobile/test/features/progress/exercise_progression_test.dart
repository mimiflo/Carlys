import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/screens/exercise_progression_screen.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/exercise_cardio_chart.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/exercise_progression_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_progress_repository.dart';

/// La courbe par exercice : la route serveur `GET /progress/exercises/:id`
/// était écrite et testée depuis septembre, et n'avait AUCUN client.
void main() {
  ExerciseProgressionPoint point(
    int jour, {
    double? charge,
    double volume = 1200,
    int metres = 0,
    int secondes = 0,
  }) => ExerciseProgressionPoint(
    sessionId: 's-$jour',
    date: DateTime.utc(2026, 8, jour, 18),
    volumeKg: volume,
    maxWeightKg: charge,
    maxReps: charge == null ? null : 8,
    distanceMeters: metres,
    durationSeconds: secondes,
  );

  ExerciseProgressionEntity progression({
    required List<ExerciseProgressionPoint> points,
    List<PersonalRecordEntry> records = const [],
  }) => ExerciseProgressionEntity(
    exerciseId: 'ex-1',
    exerciseName: 'Développé couché',
    records: records,
    points: points,
  );

  Widget host(FakeProgressRepository repository) => ProviderScope(
    overrides: [progressRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const ExerciseProgressionScreen(exerciseId: 'ex-1'),
    ),
  );

  FakeProgressRepository avec(ExerciseProgressionEntity data) {
    final repository = FakeProgressRepository();
    repository.exerciseProgressions['ex-1'] = data;
    return repository;
  }

  testWidgets('la courbe se trace et l’écran interroge bien la route', (
    tester,
  ) async {
    final repository = avec(
      progression(
        points: [
          point(1, charge: 60),
          point(8, charge: 62.5),
          point(15, charge: 65),
        ],
      ),
    );

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(
      repository.requestedExerciseIds,
      ['ex-1'],
      reason:
          'L’écran doit consommer la route dédiée, pas recomposer la courbe '
          'depuis les statistiques agrégées.',
    );
    expect(find.byType(ExerciseProgressionChart), findsOneWidget);
    expect(find.text('Développé couché'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('les records sont MARQUÉS sur le tracé, pas listés à côté', (
    tester,
  ) async {
    final repository = avec(
      progression(
        points: [
          point(1, charge: 60),
          point(8, charge: 62.5),
          point(15, charge: 65),
        ],
        records: [
          PersonalRecordEntry(
            id: 'r-1',
            exerciseId: 'ex-1',
            exerciseName: 'Développé couché',
            type: PersonalRecordType.maxWeight,
            value: 65,
            achievedAt: DateTime.utc(2026, 8, 15, 18),
          ),
        ],
      ),
    );

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    // La légende n'apparaît QUE s'il y a un point marqué : c'est ce qui
    // prouve que le record a été rapproché de sa séance, au jour près.
    expect(find.text('Le point accentué est un record'), findsOneWidget);
    expect(find.text('Records sur cet exercice'), findsOneWidget);
  });

  testWidgets('un record d’un AUTRE jour ne marque aucun point', (
    tester,
  ) async {
    final repository = avec(
      progression(
        points: [point(1, charge: 60), point(8, charge: 62.5)],
        records: [
          PersonalRecordEntry(
            id: 'r-1',
            exerciseId: 'ex-1',
            exerciseName: 'Développé couché',
            type: PersonalRecordType.maxWeight,
            value: 65,
            // Aucune séance ce jour-là dans les points servis.
            achievedAt: DateTime.utc(2026, 7, 2, 18),
          ),
        ],
      ),
    );

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.textContaining('point accentué'), findsNothing);
    expect(find.textContaining('points accentués'), findsNothing);
  });

  testWidgets('sans charge notée : on le DIT, pas de ligne plate à zéro', (
    tester,
  ) async {
    // Tractions au poids du corps : du volume, aucune charge. Une courbe
    // tracée sur des zéros raconterait une stagnation qui n'existe pas.
    final repository = avec(
      progression(points: [point(1), point(8), point(15)]),
    );

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseProgressionChart), findsNothing);
    expect(find.byType(ExerciseCardioChart), findsNothing);
    expect(find.text('Pas encore de courbe'), findsOneWidget);
    expect(
      find.textContaining('ni charge, ni chrono, ni distance'),
      findsOneWidget,
    );
    // Les séances restent listées : elles ont bien eu lieu.
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('une seule séance chargée : la courbe attend la deuxième', (
    tester,
  ) async {
    final repository = avec(
      progression(points: [point(1, charge: 60), point(8)]),
    );

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.byType(ExerciseProgressionChart), findsNothing);
    expect(find.textContaining('se trace à partir de deux'), findsOneWidget);
  });

  testWidgets('aucune séance : un état vide qui dit quoi faire', (
    tester,
  ) async {
    final repository = avec(progression(points: const []));

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Aucune séance sur cet exercice'), findsOneWidget);
  });

  testWidgets('serveur muet : une erreur avec son réessai', (tester) async {
    // Le dépôt ne connaît pas cet exercice : il lève.
    final repository = FakeProgressRepository();

    await tester.pumpWidget(host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Progression indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  group('Le CARDIO a sa propre courbe', () {
    testWidgets('une course se trace en kilomètres, pas en kilos', (
      tester,
    ) async {
      // Le cas qui a motivé la tranche : la charge maximale d'une course
      // vaut `null`, et l'écran rendait « pas encore de courbe » à quelqu'un
      // qui courait depuis six mois.
      final repository = avec(
        progression(
          points: [
            point(1, volume: 0, metres: 5000, secondes: 1800),
            point(8, volume: 0, metres: 6500, secondes: 2100),
            point(15, volume: 0, metres: 8000, secondes: 2400),
          ],
        ),
      );

      await tester.pumpWidget(host(repository));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseCardioChart), findsOneWidget);
      expect(find.byType(ExerciseProgressionChart), findsNothing);
      expect(find.text('DISTANCE PAR SÉANCE'), findsOneWidget);
      // Le cumul dit ce que la courbe ne dit pas : 19,5 km au total.
      expect(find.text('19,5 km sur 3 séances'), findsOneWidget);
    });

    testWidgets('sans distance notée, c’est le CHRONO qui monte en ordonnée', (
      tester,
    ) async {
      final repository = avec(
        progression(
          points: [
            point(1, volume: 0, secondes: 1800),
            point(8, volume: 0, secondes: 2400),
          ],
        ),
      );

      await tester.pumpWidget(host(repository));
      await tester.pumpAndSettle();

      expect(find.text('TEMPS D’EFFORT PAR SÉANCE'), findsOneWidget);
      expect(find.text('70:00 min sur 2 séances'), findsOneWidget);
    });

    testWidgets('un exercice HYBRIDE suit ce que ses séances racontent', (
      tester,
    ) async {
      // Le rameur : deux séances chargées, trois en cardio. On trace UNE
      // courbe, celle de la majorité des faits — pas celle d'une étiquette
      // d'exercice, qu'une fiche mal catégorisée rendrait fausse.
      final repository = avec(
        progression(
          points: [
            point(1, charge: 40),
            point(3, charge: 42),
            point(8, volume: 0, metres: 2000, secondes: 600),
            point(10, volume: 0, metres: 2400, secondes: 660),
            point(15, volume: 0, metres: 3000, secondes: 720),
          ],
        ),
      );

      await tester.pumpWidget(host(repository));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseCardioChart), findsOneWidget);
      expect(find.byType(ExerciseProgressionChart), findsNothing);
    });

    testWidgets('une séance de course s’écrit avec ses chiffres à elle', (
      tester,
    ) async {
      final repository = avec(
        progression(
          points: [
            point(1, volume: 0, metres: 5000, secondes: 1800),
            point(8, volume: 0, metres: 6500, secondes: 2100),
          ],
        ),
      );

      await tester.pumpWidget(host(repository));
      await tester.pumpAndSettle();

      // La ligne de séance affichait « — » et « 0 kg », c'est-à-dire un
      // échec là où il y avait cinq kilomètres.
      expect(find.text('6,5 km'), findsOneWidget);
      expect(find.text('35:00 min'), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    test('la lecture se décide sur les FAITS, à égalité la distance gagne', () {
      final distanceEtChrono = progression(
        points: [
          point(1, volume: 0, metres: 5000, secondes: 1800),
          point(8, volume: 0, metres: 6500, secondes: 2100),
        ],
      );
      expect(distanceEtChrono.cardioReading, CardioReading.distance);

      final surtoutDuChrono = progression(
        points: [
          point(1, volume: 0, metres: 5000, secondes: 1800),
          point(8, volume: 0, secondes: 2100),
          point(15, volume: 0, secondes: 2400),
        ],
      );
      expect(surtoutDuChrono.cardioReading, CardioReading.duration);
    });
  });
}
