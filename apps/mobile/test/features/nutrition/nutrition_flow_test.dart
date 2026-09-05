import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/dna_helix.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/metabolic_profile_form.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart' as navigation;

Widget appWith(FakeNutritionRepository nutrition) => ProviderScope(
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
        nutritionRepositoryProvider.overrideWithValue(nutrition),
      ],
      child: const CarlysApp(),
    );

/// L'écran nutrition SEUL, sur sa route : le harnais resserré des tests de
/// défilement, où la taille de fenêtre décide de ce que la liste paresseuse
/// a déjà construit.
Widget screenWith(FakeNutritionRepository nutrition) => ProviderScope(
      overrides: [
        nutritionRepositoryProvider.overrideWithValue(nutrition),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const NutritionScreen(),
      ),
    );

/// Rend visible un élément de l'écran courant (dernier Scrollable de la pile).
Future<void> reveal(WidgetTester tester, Finder item) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.drag(scrollable, const Offset(0, 2000), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(item, 150, scrollable: scrollable);
  await tester.pumpAndSettle();
}

Future<void> openNutritionTab(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await navigation.openNutrition(tester);
}

void main() {
  setUp(() {
    // Parcours de première ouverture déjà terminé.
    seedCompletedFirstRun();
  });

  group('réduction d’animations active (hélice statique)', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    testWidgets('profil incomplet : manquants listés et formulaire affiché',
        (tester) async {
      await tester.pumpWidget(appWith(FakeNutritionRepository()));
      await openNutritionTab(tester);

      expect(find.text('Informations manquantes'), findsOneWidget);
      expect(find.text('Sexe biologique'), findsWidgets);
      expect(find.text('Poids (mesure corporelle)'), findsOneWidget);
      expect(find.byType(DnaHelix), findsOneWidget);

      // Le hero ne sert pas l'absence comme un chiffre : ni tiret géant en
      // accent, ni libellé de dépense sous un vide — une phrase, et la porte.
      expect(find.text('—'), findsNothing);
      expect(find.text('KCAL / DÉPENSE TOTALE'), findsNothing);
      expect(find.text('Compléter mon profil'), findsOneWidget);

      // Le poids manque : l'app renvoie vers les mesures corporelles.
      await reveal(tester, find.textContaining('mesures corporelles'));
      expect(find.textContaining('mesures corporelles'), findsOneWidget);

      // Tant que le profil est incomplet, le formulaire vient AVANT le
      // journal : le seul geste utile du premier jour n'est pas en bas de
      // page.
      await reveal(tester, find.text('Journal du jour'));
      expect(
        tester.getTopLeft(find.byType(MetabolicProfileForm)).dy,
        lessThan(tester.getTopLeft(find.text('Journal du jour')).dy),
      );
    });

    testWidgets('profil incomplet : le bouton du hero mène au formulaire',
        (tester) async {
      await tester.pumpWidget(appWith(FakeNutritionRepository()));
      await openNutritionTab(tester);

      // Avant : le formulaire est sous le pli (construit d'avance par la
      // liste paresseuse, mais pas un pixel n'en est visible).
      final screen = tester.getSize(find.byType(NutritionScreen));
      expect(
        tester.getTopLeft(find.byType(MetabolicProfileForm)).dy,
        greaterThanOrEqualTo(screen.height),
      );

      await tester.tap(find.text('Compléter mon profil'));
      await tester.pumpAndSettle();

      // Après : son en-tête est en haut de l'écran, le formulaire visible.
      final formTop = tester.getTopLeft(find.byType(MetabolicProfileForm)).dy;
      expect(formTop, greaterThanOrEqualTo(0));
      expect(formTop, lessThan(screen.height / 2));
    });

    testWidgets(
        'fenêtre courte : le bouton du hero descend jusqu’au formulaire '
        'pas encore construit', (tester) async {
      // 393 × 400 points : la liste paresseuse n'a pas construit le
      // formulaire quand le bouton est pressé — c'est la branche de repli
      // de _revealProfile (descendre d'abord, caler ensuite) qui répond.
      tester.view.physicalSize = const Size(1179, 1200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(screenWith(FakeNutritionRepository()));
      await tester.pumpAndSettle();

      expect(find.byType(MetabolicProfileForm), findsNothing);

      // La liste est attachée au contrôleur PRIMAIRE de la route : c'est
      // lui que le tap sur la barre d'état iOS pilote — un contrôleur
      // privé retirait l'écran de ce geste.
      final primary = PrimaryScrollController.of(
        tester.element(find.byType(NutritionScreen)),
      );
      expect(primary.hasClients, isTrue);

      await tester.tap(find.text('Compléter mon profil'));
      await tester.pumpAndSettle();

      // Le formulaire est construit et visible dans la fenêtre.
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final formTop = tester.getTopLeft(find.byType(MetabolicProfileForm)).dy;
      expect(formTop, greaterThanOrEqualTo(0));
      expect(formTop, lessThan(screenHeight));
    });

    testWidgets('formulaire complété : le rapport métabolique apparaît',
        (tester) async {
      final nutrition = FakeNutritionRepository(weightKg: 80);
      await tester.pumpWidget(appWith(nutrition));
      await openNutritionTab(tester);

      await reveal(tester, find.text('Homme'));
      await tester.tap(find.text('Homme'));
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Choisir une date'));
      await tester.tap(find.text('Choisir une date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await reveal(tester, find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), '180');

      await reveal(tester, find.text('Choisir un niveau'));
      await tester.tap(find.byType(DropdownButtonFormField<ActivityLevel>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Modérément actif').last);
      await tester.pumpAndSettle();

      await reveal(tester, find.text('Enregistrer mon profil'));
      await tester.tap(find.text('Enregistrer mon profil'));
      await tester.pumpAndSettle();

      expect(nutrition.updateCount, 1);
      // La page s'est ALLONGÉE (journal du jour) et la ListView est
      // paresseuse : chaque zone s'atteste une fois rendue visible.
      // 1. Le hero, en tête : dépense totale et corpulence.
      await reveal(tester, find.text('CORPULENCE NORMALE'));
      expect(
        find.textContaining('2\u202F759', findRichText: true),
        findsWidgets,
      );
      // 2. Les macros, plus bas.
      await reveal(tester, find.text('Macros'));
      expect(find.textContaining('OBJECTIF'), findsOneWidget);
      expect(find.text('128 g'), findsOneWidget);
    });

    testWidgets('profil complet : résultats, IMC et hydratation affichés',
        (tester) async {
      await tester.pumpWidget(
        appWith(
          FakeNutritionRepository(
            weightKg: 80,
            sex: BiologicalSex.male,
            birthDate: DateTime.utc(1996, 3, 12),
            heightCm: 180,
            activityLevel: ActivityLevel.moderate,
            goal: NutritionGoal.maintain,
          ),
        ),
      );
      await openNutritionTab(tester);

      expect(find.textContaining('OBJECTIF'), findsOneWidget);
      expect(find.text('24,7'), findsOneWidget);
      // Le hero donne le chiffre, pas une invitation.
      expect(find.text('Compléter mon profil'), findsNothing);
      await reveal(tester, find.textContaining('2,8'));
      expect(find.textContaining('2,8'), findsWidgets);
      // Profil complet : le journal garde sa place AVANT le formulaire.
      await reveal(tester, find.text('Journal du jour'));
      expect(
        tester.getTopLeft(find.byType(MetabolicProfileForm)).dy,
        greaterThan(tester.getTopLeft(find.text('Journal du jour')).dy),
      );
      // L'objectif nutritionnel reste lisible dans le formulaire de profil.
      await reveal(tester, find.text('Maintenir'));
      expect(find.text('Maintenir'), findsWidgets);
      // Le profil reste modifiable sous les résultats.
      await reveal(tester, find.text('Enregistrer mon profil'));
      expect(find.text('Enregistrer mon profil'), findsOneWidget);
    });
  });

  group('journal du jour', () {
    setUp(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });

    testWidgets('ajout par la feuille : le repas et le total apparaissent',
        (tester) async {
      final nutrition = FakeNutritionRepository(
        weightKg: 80,
        sex: BiologicalSex.male,
        birthDate: DateTime.utc(1996, 3, 12),
        heightCm: 180,
        activityLevel: ActivityLevel.moderate,
        goal: NutritionGoal.maintain,
      );
      await tester.pumpWidget(appWith(nutrition));
      await openNutritionTab(tester);

      await reveal(tester, find.text('Journal du jour'));
      expect(find.textContaining('Rien au journal'), findsOneWidget);

      await tester.tap(find.text('Ajouter un repas'));
      await tester.pumpAndSettle();
      // Les champs DE LA FEUILLE, dans l'ordre : repas, kcal, protéines —
      // bornés à la feuille : le formulaire de profil, derrière, a les
      // siens.
      final fields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), 'Skyr, granola');
      await tester.enterText(fields.at(1), '654');
      await tester.tap(find.text('Ajouter au journal'));
      await tester.pumpAndSettle();

      // Le repas est écrit dans le dépôt ET rendu à l'écran, total en tête.
      expect(nutrition.meals, hasLength(1));
      await reveal(tester, find.text('Skyr, granola'));
      // L'en-tête de section rend son texte de droite en MAJUSCULES mono.
      expect(find.text('654 / 2 759 KCAL'), findsOneWidget);

      // Suppression : le journal se vide.
      await tester.tap(find.byTooltip('Retirer ce repas'));
      await tester.pumpAndSettle();
      expect(nutrition.meals, isEmpty);
      expect(find.textContaining('Rien au journal'), findsOneWidget);
    });
  });

  testWidgets('hélice ADN : animation en boucle par défaut', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DnaHelix())),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DnaHelix), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    // Bounded pumps uniquement : l'animation ne « settle » jamais.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('hélice ADN : statique quand les animations sont réduites',
      (tester) async {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .accessibilityFeaturesTestValue = FakeAccessibilityFeatures.allOn;
    addTearDown(
      TestWidgetsFlutterBinding
          .instance.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DnaHelix())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DnaHelix), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
