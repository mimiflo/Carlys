import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_workout_repository.dart';

Widget appWith(FakeProgressRepository progress) => ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider
            .overrideWithValue(FakeAuthRepository(storedSession: true)),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
        progressRepositoryProvider.overrideWithValue(progress),
      ],
      child: const CarlysApp(),
    );

/// Rend visible un élément de l'écran COURANT (dernier Scrollable de la
/// pile) : remonte d'abord en haut, puis descend jusqu'à la cible —
/// déterministe quelle que soit la position de défilement précédente.
Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.drag(scrollable, const Offset(0, 2000), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(item, 150, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('parcours : accueil → progression (stats, records, poids)',
      (tester) async {
    final progress = FakeProgressRepository(
      records: [
        recordOf('Développé couché', PersonalRecordType.maxWeight, 80),
        recordOf('Développé couché', PersonalRecordType.maxReps, 12),
        recordOf('Squat', PersonalRecordType.maxWeight, 120),
      ],
      bodyMetrics: [
        BodyMetricEntry(
          id: 'w-1',
          kind: BodyMetricKind.weightKg,
          value: 84,
          measuredAt: DateTime.utc(2026, 7, 28, 7),
        ),
        BodyMetricEntry(
          id: 'w-2',
          kind: BodyMetricKind.weightKg,
          value: 82.5,
          measuredAt: DateTime.utc(2026, 8, 6, 7),
        ),
      ],
    );

    await tester.pumpWidget(appWith(progress));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Progression'));
    await tester.tap(find.text('Progression'));
    await tester.pumpAndSettle();

    // Statistiques de la période.
    expect(find.text('Séances'), findsOneWidget);
    expect(find.text('1540 kg'), findsOneWidget);
    expect(find.text('1 h 30'), findsOneWidget);

    // Changement de période → nouvelle requête (sélecteur en haut d'écran).
    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(progress.requestedPeriods, contains(ProgressPeriod.month));

    // Records regroupés par exercice (plus bas dans la page).
    await reveal(tester, find.text('Squat'));
    expect(find.text('Développé couché'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
    expect(find.text('12 rép.'), findsOneWidget);

    // Poids corporel : dernières mesures, plus récente en premier.
    await reveal(tester, find.text('84 kg'));
    expect(find.text('82.5 kg'), findsOneWidget);
  });

  testWidgets('ajoute puis supprime une mesure de poids', (tester) async {
    final progress = FakeProgressRepository();

    await tester.pumpWidget(appWith(progress));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Progression'));
    await tester.tap(find.text('Progression'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Aucune mesure enregistrée'));

    // Ajout : la feuille propose 70 kg par défaut, +0,5 → 70,5 kg.
    await reveal(tester, find.text('Ajouter mon poids'));
    await tester.tap(find.text('Ajouter mon poids'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Augmenter le poids'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('70.5 kg'));
    expect(find.text('Aucune mesure enregistrée'), findsNothing);

    // Suppression rejouable côté API ; ici la liste redevient vide.
    await reveal(tester, find.byIcon(AppIcons.delete));
    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Aucune mesure enregistrée'));
    expect(find.text('Aucune mesure enregistrée'), findsOneWidget);
  });

  testWidgets('statistiques indisponibles : état d’erreur avec réessai',
      (tester) async {
    final progress = _FailingOverviewRepository();

    await tester.pumpWidget(appWith(progress));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Progression'));
    await tester.tap(find.text('Progression'));
    await tester.pumpAndSettle();

    expect(find.text('Statistiques indisponibles'), findsOneWidget);

    progress.failOverview = false;
    await tester.tap(find.text('Réessayer').first);
    await tester.pumpAndSettle();

    expect(find.text('Statistiques indisponibles'), findsNothing);
    expect(find.text('Séances'), findsOneWidget);
  });
}

class _FailingOverviewRepository extends FakeProgressRepository {
  bool failOverview = true;

  @override
  Future<ProgressOverviewEntity> overview(ProgressPeriod period) {
    if (failOverview) {
      return Future.error(Exception('réseau indisponible'));
    }
    return super.overview(period);
  }
}
