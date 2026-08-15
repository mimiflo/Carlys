import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/dashboard/presentation/screens/home_screen.dart';
import 'package:carlys_mobile/features/onboarding/presentation/controllers/splash_gate.dart';
import 'package:carlys_mobile/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/brand_signature.dart';
import 'package:carlys_mobile/features/onboarding/presentation/widgets/splash_brand_intro.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// PAGE DE CHARGEMENT : la marque s'installe, puis s'efface d'elle-même.
///
/// Deux exigences opposées se gardent ici. Elle doit TENIR : la restauration
/// étant quasi instantanée, sans plancher le logo passerait en un battement
/// de cil. Et elle doit CÉDER : un écran de démarrage qui reste est un écran
/// bloqué, le pire défaut possible au lancement.
///
/// Ces tests avancent l'horloge à la main plutôt qu'avec `pumpAndSettle` :
/// l'accueil porte des scènes 3D qui bouclent, et attendre qu'elles se
/// taisent n'arriverait jamais. Ce qui se vérifie ici, c'est le passage
/// d'un écran à l'autre, pas leur quiétude.
void main() {
  setUp(seedCompletedFirstRun);

  Widget app({bool storedSession = true}) => ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              flavor: AppFlavor.development,
              apiBaseUrl: 'http://localhost:3000',
            ),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedSession: storedSession),
          ),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      );

  /// Laisse passer le plancher, la frame de redirection, puis la transition
  /// de page — l'écran sortant reste monté tant qu'elle dure, et le chercher
  /// trop tôt le trouverait encore.
  Future<void> letHoldElapse(WidgetTester tester) async {
    await tester.pump(splashHold);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('le logo tient l’écran, puis l’application s’ouvre seule',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    // La marque est là dès la première frame : pas d'écran vide, pas de
    // saut de couleur avant qu'elle n'apparaisse.
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(BrandSignature), findsOneWidget);

    // À mi-course, on est toujours sur la marque : c'est tout l'intérêt du
    // plancher, la session étant restaurée depuis longtemps.
    await tester.pump(splashHold * 0.5);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // Et elle cède d'elle-même, sans le moindre geste.
    await letHoldElapse(tester);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('le plancher est un minimum, pas une addition', (tester) async {
    // Sans session stockée, la restauration finit sur « non connecté » : la
    // page de connexion s'ouvre au TERME du plancher, pas après le plancher
    // PLUS le temps de restauration.
    await tester.pumpWidget(app(storedSession: false));
    await tester.pump();
    await letHoldElapse(tester);

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('réduction d’animations : aucun temps mort imposé',
      (tester) async {
    // Qui demande moins d'animations ne demande pas d'attendre plus
    // longtemps devant un logo.
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('la barre se remplit depuis la gauche, et elle se voit',
      (tester) async {
    // DEUX PANNES SILENCIEUSES sont gardées ici, toutes deux invisibles au
    // compilateur comme aux autres tests.
    //
    // La première : le remplissage n'avait aucune hauteur. Sous contraintes
    // lâches, une boîte décorée sans enfant se réduit à rien, et la barre
    // restait vide du début à la fin.
    //
    // La seconde : le découpage ne fait que la largeur parcourue, et la pile
    // centre ses enfants. La barre se remplissait donc depuis son MILIEU,
    // avec la tête lumineuse détachée du dégradé.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SplashBrandIntro(onFinished: () {})),
      ),
    );
    await tester.pump(splashHold * 0.5);

    RenderBox boxOf(bool Function(BoxDecoration) match) =>
        tester.renderObject<RenderBox>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                match(widget.decoration! as BoxDecoration),
          ),
        );

    final rail = boxOf((d) => d.color == AppColors.darkBorderStrong);
    final fill = boxOf((d) => d.gradient == AppColors.signature);

    expect(fill.size.height, greaterThan(0));
    expect(
      fill.localToGlobal(Offset.zero).dx,
      rail.localToGlobal(Offset.zero).dx,
      reason: 'le dégradé doit partir du bord gauche du rail',
    );
  });

  testWidgets('la scène ne boucle pas et annonce sa fin', (tester) async {
    // Une animation d'ambiance en boucle ferait tourner `pumpAndSettle`
    // jusqu'à son délai de garde. Toute la suite de tests monte
    // l'application par l'écran de démarrage : ce serait une panne
    // générale, pas un détail. La scène est donc éprouvée SEULE, là où
    // `pumpAndSettle` a un sens.
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplashBrandIntro(onFinished: () => finished++),
        ),
      ),
    );

    expect(finished, 0);
    await tester.pumpAndSettle();
    expect(finished, 1);
  });
}
