import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/app/restore/app_restore.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/change_password_screen.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/delete_account_screen.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_workout_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/navigation.dart';
import '../../support/noop_local_account_purge.dart';

/// LE GROUPE « COMPTE » DES RÉGLAGES.
///
/// Deux routes livrées côté serveur n'étaient joignables par aucun geste :
/// changer son mot de passe, et supprimer son compte. Ce dernier point n'est
/// pas négociable — Google Play et l'App Store refusent la publication d'une
/// application où l'on crée un compte sans pouvoir le supprimer depuis
/// l'application elle-même. On vérifie donc le CHEMIN complet, du profil à
/// l'écran, pas seulement l'existence des écrans.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    // Les scènes 3D bouclent en continu : réduction d'animations pour que
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

  Widget app() => ProviderScope(
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
      syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
      appRestoreProvider.overrideWithValue(NoopAppRestore()),
      localAccountPurgeProvider.overrideWithValue(NoopLocalAccountPurge()),
    ],
    child: const CarlysApp(),
  );

  /// Fait venir une ligne du profil sous les yeux : la page est longue.
  Future<void> reveal(WidgetTester tester, Finder item) async {
    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(item, 150, scrollable: scrollable);
    await tester.pumpAndSettle();
  }

  Future<void> openProfileScreen(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await openProfile(tester);
  }

  testWidgets('le profil porte un groupe « Compte » avec ses deux lignes', (
    tester,
  ) async {
    await openProfileScreen(tester);
    await reveal(tester, find.text('Supprimer mon compte'));

    expect(find.text('COMPTE'), findsOneWidget);
    expect(find.text('Changer mon mot de passe'), findsOneWidget);
    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets('« Changer mon mot de passe » ouvre l’écran dédié', (
    tester,
  ) async {
    await openProfileScreen(tester);
    await reveal(tester, find.text('Changer mon mot de passe'));
    await tester.tap(find.text('Changer mon mot de passe'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });

  testWidgets('« Supprimer mon compte » ouvre l’écran de suppression', (
    tester,
  ) async {
    await openProfileScreen(tester);
    await reveal(tester, find.text('Supprimer mon compte'));
    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(find.text('Effacé tout de suite'), findsOneWidget);
  });
}
