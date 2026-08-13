import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/demo/demo_overrides.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/presentation/controllers/exercise_library_controller.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/muscle_group_card.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_plan_card.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';

/// Le mode démo doit ouvrir l'application SANS serveur : session déjà
/// ouverte, catalogue, progression et nutrition servis en mémoire.
/// (Le dépôt de séances reste réel — Drift — donc doublé ici comme dans
/// tous les tests de widgets.)
Widget demoApp() => ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.demo,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        ...demoOverrides(),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
      ],
      child: const CarlysApp(),
    );

Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.drag(scrollable, const Offset(0, 2000), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(item, 150, scrollable: scrollable);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // Par défaut : appareil dont le parcours de première ouverture est
    // terminé. Le premier lancement a son propre test ci-dessous.
    seedCompletedFirstRun();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('démarre connecté, sans réseau', (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Visiteur'), findsWidgets);
  });

  testWidgets('premier lancement : le parcours est présenté puis laisse entrer',
      (tester) async {
    seedFirstOpen();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    // 0. La page de marque ouvre le parcours, en démo comme ailleurs. Son
    // bouton est en pied de page : on défile jusqu'à lui — le harnais de test
    // dessine des glyphes carrés, bien plus larges que les vraies fontes, et
    // la page s'allonge d'autant.
    final start = find.text('COMMENCER MON PARCOURS');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    // 1. Onboarding — la session démo étant déjà ouverte, l'étape « compte »
    // est satisfaite : « Passer » enchaîne directement sur Premium.
    expect(find.text('1/5'), findsOneWidget);
    // Les cartes d'identité poussent le pied de page sous le pli.
    await tester.ensureVisible(find.text('Passer'));
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    // 2. Temps d'arrêt Premium, sans croix de fermeture.
    expect(find.text('CARLYS PREMIUM'), findsOneWidget);
    expect(find.byIcon(AppIcons.close), findsNothing);

    // 3. Repli gratuit explicite, puis l'application s'ouvre.
    await tester.tap(find.text('Continuer sans Premium'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer en version gratuite'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomBar), findsOneWidget);
  });

  testWidgets('bibliothèque servie en mémoire', (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    await openExerciseLibrary(tester);

    // La bibliothèque s'ouvre désormais sur la GRILLE des groupes musculaires :
    // « Tous les mouvements » est la porte vers le catalogue entier. On vise
    // la CARTE et non son libellé : sur la petite surface de test, le bas des
    // cartes passe sous la barre d'onglets flottante.
    await tester.tap(
      find.widgetWithText(MuscleGroupCard, 'Tous les mouvements'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Développé couché'), findsOneWidget);

    // Le catalogue de démonstration est engendré depuis le seed : il compte
    // des dizaines de mouvements, paginés. « Squat » n'est donc pas sur la
    // première page — on le rejoint par la recherche, qui interroge elle
    // aussi le catalogue entier.
    await tester.enterText(find.byType(AppSearchField), 'squat');
    await tester.pump(ExerciseLibraryController.searchDebounce);
    await tester.pumpAndSettle();

    expect(find.text('Squat barre'), findsOneWidget);
  });

  testWidgets('modèles de séance servis en mémoire', (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    // « Lancer un modèle » : l'entrée naturelle, sous le démarrage de séance.
    // La carte « séance du jour » est passée sous le résumé du jour, et
    // la liste est PARESSEUSE : il faut défiler jusqu'à elle pour
    // qu'elle existe.
    await tester.scrollUntilVisible(
      find.text('Lancer un modèle'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lancer un modèle'));
    await tester.pumpAndSettle();

    expect(find.text('Mes modèles'), findsOneWidget);
    expect(find.text('Push — Force'), findsOneWidget);
    expect(find.text('Pull — Hypertrophie'), findsOneWidget);
  });

  testWidgets('nutrition complète servie en mémoire', (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    await openNutrition(tester);

    // L'objectif calorique est annoncé par l'en-tête « Macros » ; les
    // milliers sont séparés par une espace fine insécable.
    expect(find.text('Macros'), findsOneWidget);
    expect(
      find.textContaining('3\u202F040', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('progression et abonnement premium servis en mémoire',
      (tester) async {
    await tester.pumpWidget(demoApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomBar),
        matching: find.text('Progrès'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SÉANCES'), findsOneWidget);

    // L'abonnement se rejoint depuis l'onglet Profil.
    await openProfile(tester);
    // L'abonnement s'ouvre depuis la bannière de plan du profil.
    await reveal(tester, find.byType(ProfilePlanCard));
    await tester.tap(find.byType(ProfilePlanCard));
    await tester.pumpAndSettle();
    expect(find.textContaining('Premium (démo)'), findsWidgets);
  });
}
