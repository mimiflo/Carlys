import 'dart:async';

import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_grid.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_primer.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/today_section.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/controllers/water_controllers.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_community_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// L'ACCUEIL NE MENT PAS SUR CE QU'IL SAIT.
///
/// La section « Aujourd'hui » se décidait sur `valueOrNull == null`, qui vaut
/// `null` pendant le chargement ET en erreur autant que faute de cible. Hors
/// réseau, l'écran le plus visité annonçait donc à l'utilisateur qu'il
/// n'avait rien configuré, et l'invitait à recommencer un profil qu'il avait
/// déjà rempli.
///
/// Ce fichier défend la distinction : l'amorçage n'appartient QU'AU cas où le
/// serveur a répondu, et qu'il n'a pas de cible.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    // La scène cœur boucle en continu : réduction d'animations pour que
    // pumpAndSettle converge.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  /// Un profil COMPLET, dont le serveur refuse malgré tout de parler : c'est
  /// le cas qui piège, celui d'un compte configuré et d'un réseau absent.
  FakeNutritionRepository refusing(Object failure) => FakeNutritionRepository(
    weightKg: 80,
    sex: BiologicalSex.male,
    birthDate: DateTime.utc(1996, 3, 12),
    heightCm: 180,
    activityLevel: ActivityLevel.moderate,
    goal: NutritionGoal.gainMuscle,
    failure: failure,
  );

  /// L'accueil complet, monté comme dans `home_screen_test.dart` : TOUS les
  /// dépôts sont doublés, sans quoi une vraie base Drift s'ouvre.
  Future<void> pumpHome(
    WidgetTester tester,
    FakeNutritionRepository nutrition,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.development,
              apiBaseUrl: 'http://localhost:3000',
            ),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedSession: true),
          ),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          nutritionRepositoryProvider.overrideWithValue(nutrition),
          waterStoreProvider.overrideWithValue(FakeWaterStore()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// La page est plus longue que l'écran et la ListView est PARESSEUSE : on
  /// défile jusqu'à la SECTION, jamais jusqu'au texte attendu.
  ///
  /// `TodaySection` existe dans les trois états (on attend, on n'a pas pu, on
  /// sait) ; un texte, lui, n'existe que dans le sien. Viser le texte faisait
  /// donc mourir `scrollUntilVisible` sur « Bad state: No element » — mesuré
  /// en réinjectant le bogue — bien AVANT l'assertion qui aurait nommé le
  /// défaut. Le test rougissait pour la bonne raison, avec un message qui
  /// n'apprenait rien.
  Future<void> scrollToToday(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byType(TodaySection),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('serveur en panne : l’accueil ne propose PAS l’amorçage', (
    tester,
  ) async {
    await pumpHome(tester, refusing(const ServerException('502')));

    await scrollToToday(tester);

    // Le mensonge exact qu'on interdit : proposer de calculer des objectifs
    // qui existent déjà, parce que le serveur n'a pas répondu. L'interdit se
    // dit EN PREMIER : c'est lui qui doit nommer l'échec.
    expect(find.byType(TodayPrimer), findsNothing);
    expect(find.text('Carlys ne sait pas encore quoi viser'), findsNothing);
    expect(find.text('Calculer mes objectifs'), findsNothing);

    // Et l'échec est dit, avec de quoi réessayer.
    expect(find.text('Objectifs indisponibles'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    // La section garde son titre : elle n'a pas disparu de la page.
    expect(find.text('AUJOURD’HUI'), findsOneWidget);
    expect(find.byType(TodayGrid), findsNothing);
  });

  testWidgets('hors ligne : le message parle du réseau, pas du profil', (
    tester,
  ) async {
    await pumpHome(tester, refusing(const NetworkException('socket')));

    await scrollToToday(tester);

    expect(find.byType(TodayPrimer), findsNothing);
    expect(find.text('Hors connexion'), findsOneWidget);
    expect(
      find.text(
        'Tes objectifs du jour se calculent sur le serveur : '
        'ils reviennent avec le réseau.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('profil vide et serveur qui répond : l’amorçage revient', (
    tester,
  ) async {
    // Le contre-exemple, sans quoi la correction pourrait consister à ne
    // JAMAIS montrer l'amorçage. Le serveur répond, il n'a pas de cible :
    // c'est le seul cas où l'invitation est vraie.
    await pumpHome(tester, FakeNutritionRepository());

    await scrollToToday(tester);

    expect(find.byType(TodayPrimer), findsOneWidget);
    expect(find.text('Calculer mes objectifs'), findsOneWidget);
    expect(find.text('Objectifs indisponibles'), findsNothing);
    expect(find.text('Hors connexion'), findsNothing);
  });

  testWidgets('serveur qui tarde : on attend, on n’invite pas', (tester) async {
    // Le chargement se teste sur la seule section : le reste de l'accueil
    // n'entre pas dans cette décision, et le dépôt muet ci-dessous fige
    // volontairement l'attente.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nutritionRepositoryProvider.overrideWithValue(
            _SilentNutritionRepository(),
          ),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          waterStoreProvider.overrideWithValue(FakeWaterStore()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TodaySection(onStartPrimer: () {}, onOpenHydration: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    // Tant qu'on ne sait pas, la section n'AFFIRME rien : ni invitation à
    // configurer, ni grille, ni échec. C'est le cœur de la correction —
    // l'attente ne doit surtout pas se lire comme « tu n'as rien rempli ».
    expect(find.byType(TodayPrimer), findsNothing);
    expect(find.text('Calculer mes objectifs'), findsNothing);
    expect(find.byType(TodayGrid), findsNothing);
    expect(find.text('Objectifs indisponibles'), findsNothing);
    expect(find.text('Hors connexion'), findsNothing);
  });
}

/// Un dépôt qui ne répond jamais : le premier chargement, figé.
class _SilentNutritionRepository extends FakeNutritionRepository {
  @override
  Future<MetabolismReport> metabolismReport() =>
      Completer<MetabolismReport>().future;
}
