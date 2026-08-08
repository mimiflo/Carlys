import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
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
import '../../support/first_run_prefs.dart';

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
        appRestoreProvider.overrideWithValue(NoopAppRestore()),
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

Future<void> openProgressTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomBar),
      matching: find.text('Progrès'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Parcours de première ouverture déjà terminé : l'application démarre
    // sur l'accueil.
    seedCompletedFirstRun();
    // Les scènes 3D (cœur, hélice) bouclent en continu : réduction
    // d'animations pour que pumpAndSettle converge.
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

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
    await openProgressTab(tester);

    // Carte de volume : 1 540 kg s'affiche en tonnes (« 1,5 t »).
    expect(find.text('VOLUME HEBDO'), findsOneWidget);
    expect(find.textContaining('1,5', findRichText: true), findsWidgets);

    // Tuiles : séances, puis durée (l'assiduité hebdomadaire n'est pas
    // calculable sur une fenêtre d'une seule semaine).
    expect(find.text('SÉANCES'), findsOneWidget);
    expect(find.textContaining('1 H 30', findRichText: true), findsOneWidget);

    // Changement de période : la pastille unique ouvre le sélecteur.
    await tester.tap(find.text('SEMAINE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    expect(progress.requestedPeriods, contains(ProgressPeriod.month));
    expect(find.text('MOIS'), findsOneWidget);

    // Records : une ligne par record, du plus récent au plus ancien.
    await reveal(tester, find.text('Squat'));
    expect(find.text('Développé couché'), findsNWidgets(2));
    expect(find.textContaining('80kg', findRichText: true), findsOneWidget);
    expect(find.textContaining('12rép.', findRichText: true), findsOneWidget);

    // Poids corporel : dernières mesures, plus récente en premier.
    await reveal(tester, find.textContaining('84kg', findRichText: true));
    expect(find.textContaining('82,5', findRichText: true), findsWidgets);
  });

  testWidgets('ouvre la liste complète des records', (tester) async {
    final progress = FakeProgressRepository(
      records: [
        recordOf('Développé couché', PersonalRecordType.maxWeight, 80),
        recordOf('Squat', PersonalRecordType.maxWeight, 120),
        recordOf('Soulevé de terre', PersonalRecordType.maxWeight, 145),
        recordOf('Rowing', PersonalRecordType.maxWeight, 70),
      ],
    );

    await tester.pumpWidget(appWith(progress));
    await tester.pumpAndSettle();
    await openProgressTab(tester);

    // Seuls trois records tiennent dans la page.
    await reveal(tester, find.text('TOUT VOIR'));
    expect(find.text('Rowing'), findsNothing);

    await tester.tap(find.text('TOUT VOIR'));
    await tester.pumpAndSettle();

    expect(find.text('Tous mes records'), findsOneWidget);
    expect(find.text('Rowing'), findsOneWidget);
  });

  testWidgets('ajoute puis supprime une mesure de poids', (tester) async {
    final progress = FakeProgressRepository();

    await tester.pumpWidget(appWith(progress));
    await tester.pumpAndSettle();
    await openProgressTab(tester);

    await reveal(tester, find.text('Aucune mesure enregistrée'));

    // Ajout : la feuille propose 70 kg par défaut, +0,5 → 70,5 kg.
    await reveal(tester, find.text('AJOUTER'));
    await tester.tap(find.text('AJOUTER'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Augmenter le poids'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    await reveal(tester, find.textContaining('70,5kg', findRichText: true));
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
    await openProgressTab(tester);

    expect(find.text('Statistiques indisponibles'), findsOneWidget);

    progress.failOverview = false;
    await tester.tap(find.text('Réessayer').first);
    await tester.pumpAndSettle();

    expect(find.text('Statistiques indisponibles'), findsNothing);
    expect(find.text('SÉANCES'), findsOneWidget);
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
