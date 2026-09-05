import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/community/presentation/screens/community_screen.dart';
import 'package:carlys_mobile/features/nutrition/data/repositories/nutrition_repository_impl.dart';
import 'package:carlys_mobile/features/progress/data/repositories/progress_repository_impl.dart';
import 'package:carlys_mobile/features/progress/presentation/screens/progress_screen.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_nutrition_repository.dart';
import '../../support/fake_progress_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';

/// Le cap du profil dans « Pour toi » : la ligne change avec l'identité
/// Carlys, mène à la partie de l'application qui sert sa devise, et n'existe
/// pas tant qu'aucun profil n'est choisi — `null` n'est jamais un défaut.
void main() {
  setUp(() {
    seedCompletedFirstRun();
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

  AuthUser userWith(CarlysProfile? profile) => AuthUser(
    id: fakeUser.id,
    email: fakeUser.email,
    displayName: fakeUser.displayName,
    emailVerified: fakeUser.emailVerified,
    locale: fakeUser.locale,
    timezone: fakeUser.timezone,
    carlysProfile: profile,
  );

  Future<void> pumpHome(WidgetTester tester, {CarlysProfile? profile}) async {
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
            FakeAuthRepository(storedSession: true, user: userWith(profile)),
          ),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
          progressRepositoryProvider.overrideWithValue(
            FakeProgressRepository(),
          ),
          nutritionRepositoryProvider.overrideWithValue(
            FakeNutritionRepository(),
          ),
          syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
          appRestoreProvider.overrideWithValue(NoopAppRestore()),
        ],
        child: const CarlysApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sans profil choisi, l’accueil ne montre aucun cap', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.textContaining('TON CAP'), findsNothing);
  });

  testWidgets('le Challenger est envoyé vers les défis de la communauté', (
    tester,
  ) async {
    await pumpHome(tester, profile: CarlysProfile.challenger);

    const cap =
        'Va chercher un défi — la communauté en lance à ta hauteur '
        'cette semaine.';
    await scrollTo(tester, find.text(cap));
    expect(find.text('TON CAP LE CHALLENGER'), findsOneWidget);

    await tester.tap(find.text(cap));
    // Pas de pumpAndSettle : sans dépôt communauté, l'écran garde son
    // indicateur de chargement animé — la navigation, elle, est immédiate.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CommunityScreen), findsOneWidget);
  });

  testWidgets('le Stratège est envoyé vers ses chiffres de progression', (
    tester,
  ) async {
    await pumpHome(tester, profile: CarlysProfile.stratege);

    const cap =
        'Comprends tes chiffres — records et tendances disent ce que '
        'ton corps répond.';
    await scrollTo(tester, find.text(cap));
    expect(find.text('TON CAP LE STRATÈGE'), findsOneWidget);

    await tester.tap(find.text(cap));
    await tester.pumpAndSettle();
    expect(find.byType(ProgressScreen), findsOneWidget);
  });
}
