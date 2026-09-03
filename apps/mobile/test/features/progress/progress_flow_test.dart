import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/demo/demo_templates.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_weight_chart.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/body_weight_latest.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/progress_first_steps.dart';
import 'package:carlys_mobile/features/progress/presentation/widgets/progress_tiles.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:carlys_mobile/features/workout_template/data/repositories/workout_template_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// Monte l'application avec TOUS ses dépôts en mémoire : l'amorçage du
/// premier jour pousse l'écran des modèles, qui lit le dépôt de modèles —
/// sans le substituer, une vraie base s'ouvre et l'écran charge sans fin.
Widget appWith(FakeProgressRepository progress) {
  final workouts = FakeWorkoutRepository();
  return ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment(
          flavor: AppFlavor.development,
          apiBaseUrl: 'http://localhost:3000',
        ),
      ),
      authRepositoryProvider
          .overrideWithValue(FakeAuthRepository(storedSession: true)),
      workoutRepositoryProvider.overrideWithValue(workouts),
      workoutTemplateRepositoryProvider
          .overrideWithValue(DemoWorkoutTemplateRepository(workouts)),
      syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
      appRestoreProvider.overrideWithValue(NoopAppRestore()),
      progressRepositoryProvider.overrideWithValue(progress),
    ],
    child: const CarlysApp(),
  );
}

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
    // Une seule mesure : un fait et une promesse, pas un graphique vide.
    expect(find.text(BodyWeightFirstMeasure.note), findsOneWidget);
    expect(find.byType(BodyWeightChart), findsNothing);

    // Suppression rejouable côté API ; ici la liste redevient vide.
    await reveal(tester, find.byIcon(AppIcons.delete));
    await tester.tap(find.byIcon(AppIcons.delete));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Aucune mesure enregistrée'));
    expect(find.text('Aucune mesure enregistrée'), findsOneWidget);
  });

  testWidgets('deux mesures : la courbe apparaît, la promesse disparaît',
      (tester) async {
    final progress = FakeProgressRepository(
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

    await reveal(tester, find.textContaining('84kg', findRichText: true));
    expect(find.byType(BodyWeightChart), findsOneWidget);
    expect(find.text(BodyWeightFirstMeasure.note), findsNothing);
  });

  testWidgets('premier jour : un seul bloc d’amorçage, ni zéros ni vides',
      (tester) async {
    // Aucune séance, aucun record, aucune mesure : trois états vides
    // empilés et deux tuiles à zéro disaient cinq fois la même absence.
    final progress = FakeProgressRepository(overviewFor: _emptyOverview);

    await tester.pumpWidget(appWith(progress));
    await tester.pumpAndSettle();
    await openProgressTab(tester);

    expect(find.byType(ProgressFirstSteps), findsOneWidget);
    expect(find.text('Rien à mesurer pour l’instant'), findsOneWidget);
    expect(find.byType(AppEmptyState), findsNothing);
    expect(find.byType(ProgressTiles), findsNothing);
    expect(find.text('SÉANCES'), findsNothing);
    expect(find.text('Aucun record pour l’instant'), findsNothing);
    expect(find.text('Aucune mesure enregistrée'), findsNothing);

    // Le second geste du premier jour : noter son poids, sans quitter
    // l'écran — et le bloc cède alors la place à la page ordinaire.
    await tester.tap(find.text('Ajouter mon poids'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.byType(ProgressFirstSteps), findsNothing);
    await reveal(tester, find.text(BodyWeightFirstMeasure.note));
    expect(find.text(BodyWeightFirstMeasure.note), findsOneWidget);
  });

  testWidgets('premier jour : « Lancer une séance » ouvre les modèles',
      (tester) async {
    final progress = FakeProgressRepository(overviewFor: _emptyOverview);

    await tester.pumpWidget(appWith(progress));
    await tester.pumpAndSettle();
    await openProgressTab(tester);

    await tester.tap(find.text('Lancer une séance'));
    await tester.pumpAndSettle();

    expect(find.text('Mes modèles'), findsOneWidget);
  });

  testWidgets('période vide, compte actif : un état vide avec sa sortie',
      (tester) async {
    // Des records, mais rien sur la période : ce n'est pas un compte neuf.
    // L'état vide reste, avec une issue, et sans tuiles à zéro dessous.
    final progress = FakeProgressRepository(
      overviewFor: _emptyOverview,
      records: [recordOf('Squat', PersonalRecordType.maxWeight, 120)],
    );

    await tester.pumpWidget(appWith(progress));
    await tester.pumpAndSettle();
    await openProgressTab(tester);

    expect(find.byType(ProgressFirstSteps), findsNothing);
    expect(find.text('Aucune séance sur la période'), findsOneWidget);
    expect(find.text('Lancer une séance'), findsOneWidget);
    expect(find.byType(ProgressTiles), findsNothing);
    expect(find.text('0 MIN'), findsNothing);
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

/// Le serveur répond, avec des zéros : aucune séance sur la période.
ProgressOverviewEntity _emptyOverview(ProgressPeriod period) => overviewOf(
      period,
      sessionsCount: 0,
      setsCount: 0,
      totalVolumeKg: 0,
      totalDurationSeconds: 0,
      points: const [],
    );

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
