import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/carlys_profile/data/repositories/carlys_profile_repository_impl.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/dashboard/presentation/screens/home_screen.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/onboarding/data/first_run_store.dart';
import 'package:carlys_mobile/features/onboarding/domain/first_run_step.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/brand_pillars.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/brand_signature.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/onboarding_height_card.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_carlys_profile_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_subscription_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// PARCOURS DE PREMIÈRE OUVERTURE : page de marque → onboarding →
/// création de compte →
/// proposition Premium → repli gratuit → accueil, puis réouvertures.
///
/// Le tunnel est entièrement piloté par la redirection du routeur : ces
/// tests montent l'application complète et ne naviguent qu'au doigt.
/// Écriture des préférences à la vitesse d'un vrai téléphone.
///
/// Le mock de `shared_preferences` répond dans la même micro-tâche, donc
/// aucune frame ne s'intercale : c'est précisément ce qui rendait le bug
/// invisible en test alors qu'il se produisait à chaque fois à l'usage.
class SlowFirstRunStore extends FirstRunStore {
  const SlowFirstRunStore();

  static const Duration delay = Duration(milliseconds: 120);

  @override
  Future<void> writeStep(FirstRunStep step) async {
    await Future<void>.delayed(delay);
    return super.writeStep(step);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAuthRepository auth;
  late FakeNutritionRepository nutrition;
  late FakeCarlysProfileRepository carlysRepo;

  setUp(() {
    seedFirstOpen();
    // Les écrans traversés portent des scènes 3D en boucle : sans réduction
    // d'animations, pumpAndSettle ne rendrait jamais la main.
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    auth = FakeAuthRepository();
    nutrition = FakeNutritionRepository();
    carlysRepo = FakeCarlysProfileRepository();
  });

  tearDown(() {
    binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  Widget app({List<Override> extra = const []}) => ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.development,
              apiBaseUrl: 'http://localhost:3000',
            ),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          carlysProfileRepositoryProvider.overrideWithValue(carlysRepo),
          nutritionRepositoryProvider.overrideWithValue(nutrition),
          subscriptionRepositoryProvider
              .overrideWithValue(FakeSubscriptionRepository()),
          progressRepositoryProvider
              .overrideWithValue(FakeProgressRepository()),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
          ...extra,
        ],
        child: const CarlysApp(),
      );

  /// Franchit la page de marque.
  ///
  /// Le bouton est en pied de page : il faut défiler jusqu'à lui. La page tient
  /// l'écran avec les vraies fontes, mais le harnais de test dessine des
  /// glyphes CARRÉS, bien plus larges — le texte s'y enroule et la page
  /// s'allonge. Défiler d'abord vaut mieux que d'accorder la mise en page à un
  /// artefact de test.
  Future<void> passWelcomePage(WidgetTester tester) async {
    final cta = find.text('COMMENCER MON PARCOURS');
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    await tester.tap(cta);
    await tester.pumpAndSettle();
  }

  /// Démarre l'application sur un écran de téléphone (les cartes de
  /// l'onboarding ont besoin de hauteur).
  ///
  /// Le tunnel s'ouvre désormais sur la PAGE DE MARQUE : sauf demande
  /// contraire, on la franchit, les tests qui suivent portant sur les étapes
  /// d'après.
  Future<void> launch(
    WidgetTester tester, {
    bool passWelcome = true,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(extra: extra));
    await tester.pumpAndSettle();

    if (passWelcome &&
        find.text('COMMENCER MON PARCOURS').evaluate().isNotEmpty) {
      await passWelcomePage(tester);
    }
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    // Les cartes d'identité allongent la première étape : on défile jusqu'à
    // la cible quand elle est sous le pli (sans effet hors d'un défilement).
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Répond aux 5 étapes de l'onboarding (l'identité d'abord) puis valide.
  Future<void> answerOnboarding(WidgetTester tester) async {
    await tapText(tester, 'LE CONSTRUCTEUR');
    await tapText(tester, 'Continuer');

    await tapText(tester, 'Prendre du muscle');
    await tapText(tester, 'Continuer');

    await tapText(tester, 'Homme');
    await tapText(tester, 'Continuer');

    await tapText(tester, 'Date de naissance');
    await tapText(tester, 'OK');
    await tester.tap(
      find.descendant(
        of: find.byType(OnboardingHeightCard),
        matching: find.byIcon(AppIcons.add),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Continuer');

    await tapText(tester, 'Actif');
    await tapText(tester, 'Terminer');
  }

  Future<void> fillRegisterForm(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Camille');
    await tester.enterText(fields.at(1), 'camille@example.com');
    await tester.enterText(fields.at(2), 'MotDePasseSolide42');
    await tapText(tester, 'Créer mon compte');
  }

  testWidgets(
      'tout premier lancement : la page de marque, avant toute question',
      (tester) async {
    await launch(tester, passWelcome: false);

    // Qui est Carlys se dit AVANT de demander quoi que ce soit.
    expect(
      find.descendant(
        of: find.byType(BrandSignature),
        matching: find.text('CARLYS'),
      ),
      findsOneWidget,
    );
    expect(find.text('L’ART DE DEVENIR'), findsOneWidget);
    // Les quatre univers sont annoncés, sans prétendre être navigables.
    expect(find.byType(BrandPillars), findsOneWidget);
    expect(find.text('1/5'), findsNothing);
    expect(find.byType(AppBottomBar), findsNothing);

    // Rien d'autre n'en sort : pas d'échappatoire vers la connexion.
    expect(find.text('J’ai déjà un compte'), findsNothing);

    await passWelcomePage(tester);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets(
      'première ouverture : marque → onboarding → inscription → Premium → '
      'gratuit → accueil', (tester) async {
    await launch(tester);

    // 1. L'application s'ouvre sur l'onboarding, pas sur l'accueil.
    expect(find.text('1/5'), findsOneWidget);
    expect(find.byType(AppBottomBar), findsNothing);

    await answerOnboarding(tester);

    // 2. Création de compte. Sans session, rien n'a encore été envoyé au
    // serveur : les réponses attendent le compte — l'identité Carlys aussi.
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(nutrition.updateCount, 0);
    expect(carlysRepo.chosen, isEmpty);

    await fillRegisterForm(tester);

    // 3. Proposition Premium : vrai temps d'arrêt, sans croix de fermeture,
    // avec les droits réels du serveur.
    expect(find.text('CARLYS PREMIUM'), findsOneWidget);
    expect(find.byIcon(AppIcons.close), findsNothing);
    expect(find.text('Programmes illimités'), findsOneWidget);
    expect(find.text('Passer à Premium'), findsOneWidget);

    // Les réponses d'onboarding sont reportées sur le profil dès que le
    // compte existe — l'identité Carlys par son propre endpoint.
    expect(nutrition.updateCount, 1);
    final report = await nutrition.metabolismReport();
    expect(report.profile.goal, NutritionGoal.gainMuscle);
    expect(report.profile.sex, BiologicalSex.male);
    expect(report.profile.heightCm, 176);
    expect(report.profile.activityLevel, ActivityLevel.active);
    expect(carlysRepo.chosen, [CarlysProfile.constructeur]);

    // 4. Refus : la version gratuite est proposée explicitement, puis
    // l'application s'ouvre.
    await tapText(tester, 'Continuer sans Premium');
    expect(find.text('Continuer en version gratuite ?'), findsOneWidget);

    await tapText(tester, 'Continuer en version gratuite');
    expect(find.byType(AppBottomBar), findsOneWidget);

    // 5. Réouverture : le tunnel ne se rejoue pas.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('1/5'), findsNothing);
  });

  testWidgets(
      'version gratuite : l’accueil s’ouvre même quand l’écriture disque '
      'traîne d’une frame', (tester) async {
    // LE BUG RÉEL, invisible avec un `pumpAndSettle` ordinaire.
    //
    // Terminer le parcours fait disparaître le pied de page : l'écran
    // d'abonnement observe l'étape et rebascule sur sa version refermable.
    // Sur un téléphone, cette frame est dessinée AVANT que les préférences
    // ne rendent la main, donc l'état est démonté quand l'attente se
    // termine. Une navigation gardée par `if (mounted)` était alors
    // silencieusement abandonnée : l'utilisateur restait bloqué sur
    // l'abonnement. `pumpAndSettle` avance l'horloge avant de dessiner et
    // inverse cet ordre, ce qui masquait le défaut.
    seedFirstRunStep(FirstRunStep.subscription);
    auth.storedSession = true;
    await launch(
      tester,
      extra: [
        firstRunStoreProvider.overrideWithValue(const SlowFirstRunStore()),
      ],
    );

    await tapText(tester, 'Continuer sans Premium');
    await tester.tap(find.text('Continuer en version gratuite'));

    // L'ordre du vrai téléphone : la frame d'abord, l'écriture ensuite.
    await tester.pump();
    await tester.pump(SlowFirstRunStore.delay);
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('CARLYS PREMIUM'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('le refus mène à Premium puis revient : aucune impasse',
      (tester) async {
    seedFirstRunStep(FirstRunStep.subscription);
    auth.storedSession = true;
    await launch(tester);

    expect(find.text('CARLYS PREMIUM'), findsOneWidget);

    // « Passer à Premium » explique où souscrire — aucun tarif inventé.
    await tapText(tester, 'Passer à Premium');
    expect(find.textContaining('App Store'), findsOneWidget);
    await tapText(tester, 'J’ai compris');

    // Le repli gratuit se rétracte aussi.
    await tapText(tester, 'Continuer sans Premium');
    await tapText(tester, 'Revenir à Premium');
    expect(find.text('Passer à Premium'), findsOneWidget);

    await tapText(tester, 'Continuer sans Premium');
    await tapText(tester, 'Continuer en version gratuite');
    expect(find.byType(AppBottomBar), findsOneWidget);
  });

  testWidgets('« Passer » franchit l’onboarding sans rien enregistrer',
      (tester) async {
    await launch(tester);

    await tapText(tester, 'Passer');

    expect(nutrition.updateCount, 0);
    expect(find.text('Créer un compte'), findsOneWidget);
  });

  testWidgets('depuis l’onboarding, la connexion reste accessible',
      (tester) async {
    await launch(tester);

    await tapText(tester, 'J’ai déjà un compte');
    expect(find.text('Connexion'), findsOneWidget);

    // Connexion réussie : le parcours reprend là où il en était.
    await tester.enterText(
      find.byType(TextFormField).first,
      'camille@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'MotDePasseSolide42',
    );
    await tapText(tester, 'Se connecter');

    expect(auth.loginCalls, 1);
    expect(find.text('1/5'), findsOneWidget);
    // Session ouverte : le lien de connexion n'a plus lieu d'être.
    expect(find.text('J’ai déjà un compte'), findsNothing);
  });

  testWidgets('réouverture au milieu du tunnel : reprise à l’étape atteinte',
      (tester) async {
    seedFirstRunStep(FirstRunStep.account);
    await launch(tester, passWelcome: false);

    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('1/5'), findsNothing);

    // Qui a déjà un compte rejoint la connexion depuis l'inscription.
    await tapText(tester, 'Se connecter');
    expect(find.text('Connexion'), findsOneWidget);
  });

  testWidgets(
      'parcours terminé et session ouverte : jamais renvoyé dans le tunnel',
      (tester) async {
    seedCompletedFirstRun();
    auth.storedSession = true;
    await launch(tester, passWelcome: false);

    expect(find.byType(AppBottomBar), findsOneWidget);
    expect(find.text('1/5'), findsNothing);
    expect(find.text('CARLYS PREMIUM'), findsNothing);
  });
}
