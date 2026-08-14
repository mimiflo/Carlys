import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/workout_history/presentation/screens/workout_history_screen.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/domain/entities/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_progress_repository.dart';
import '../../support/fake_workout_repository.dart';

/// Historique : en-tête, carte calendaire du mois et cartes de séance —
/// aucune valeur affichée qui ne vienne des séances réelles.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestWidgetsFlutterBinding
            .instance.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  final now = DateTime.now();
  final month = DateTime(now.year, now.month);
  final firstDay = DateTime(now.year, now.month, 1, 9);
  final thirdDay = DateTime(now.year, now.month, 3, 9);

  WorkoutHistoryEntry entryOf({
    required String id,
    required String name,
    required DateTime startedAt,
    required int setsCount,
    required double volumeKg,
    int? durationSeconds,
    LocalSyncState syncState = LocalSyncState.synced,
  }) =>
      WorkoutHistoryEntry(
        session: WorkoutInfo(
          id: id,
          name: name,
          status: WorkoutStatus.completed,
          startedAt: startedAt,
          durationSeconds: durationSeconds,
          syncState: syncState,
        ),
        setsCount: setsCount,
        totalVolumeKg: volumeKg,
      );

  Future<void> pumpHistory(
    WidgetTester tester, {
    List<WorkoutHistoryEntry> history = const [],
    List<PersonalRecordEntry> records = const [],
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutRepositoryProvider
              .overrideWithValue(FakeWorkoutRepository()..history = history),
          progressRepositoryProvider
              .overrideWithValue(FakeProgressRepository(records: records)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WorkoutHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('carte calendaire et cartes de séance du mois courant',
      (tester) async {
    await pumpHistory(
      tester,
      history: [
        entryOf(
          id: 'h-3',
          name: 'Push force',
          startedAt: thirdDay,
          setsCount: 22,
          volumeKg: 5200,
          durationSeconds: 54 * 60,
        ),
        entryOf(
          id: 'h-1',
          name: 'Jambes',
          startedAt: firstDay,
          setsCount: 19,
          volumeKg: 7400,
          syncState: LocalSyncState.pending,
        ),
      ],
      records: [
        PersonalRecordEntry(
          id: 'r-1',
          exerciseName: 'Développé couché',
          type: PersonalRecordType.maxWeight,
          value: 100,
          achievedAt: thirdDay,
        ),
      ],
    );

    expect(find.text('Historique'), findsOneWidget);
    expect(find.text(formatMonthYearCapitalized(month)), findsOneWidget);
    expect(find.text('2 SÉANCES'), findsOneWidget);
    expect(find.text('CE MOIS-CI'), findsOneWidget);

    expect(find.text('Push force'), findsOneWidget);
    expect(
      find.text('${formatShortDateMono(thirdDay)} · 54 MIN'),
      findsOneWidget,
    );
    // Sans durée enregistrée, le sous-titre se limite à la date.
    expect(find.text(formatShortDateMono(firstDay)), findsOneWidget);

    // Volume en tonnes et séries, via les colonnes de métriques.
    expect(find.text('VOLUME'), findsNWidgets(2));
    expect(find.text('SÉRIES'), findsNWidgets(2));
    expect(find.text('5,2 t', findRichText: true), findsOneWidget);
    expect(find.text('22', findRichText: true), findsOneWidget);

    // Pastille de record seulement sur la séance du jour du record.
    expect(find.text('PR'), findsOneWidget);

    // Séance encore en file de synchronisation.
    expect(find.byIcon(AppIcons.offline), findsOneWidget);
  });

  testWidgets('sélecteur de mois ouvert par l’icône calendrier',
      (tester) async {
    await pumpHistory(
      tester,
      history: [
        entryOf(
          id: 'h-1',
          name: 'Jambes',
          startedAt: firstDay,
          setsCount: 19,
          volumeKg: 7400,
        ),
      ],
    );

    await tester.tap(find.byIcon(AppIcons.calendar));
    await tester.pumpAndSettle();

    expect(find.text('Mois affiché'), findsOneWidget);
    expect(
      find.text(formatMonthYearCapitalized(month)),
      findsNWidgets(2),
    );
  });

  testWidgets('sans séance : état vide', (tester) async {
    await pumpHistory(tester);

    expect(find.text('Aucune séance terminée'), findsOneWidget);
  });
}
