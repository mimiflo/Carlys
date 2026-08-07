import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/synchronization/sync_lifecycle.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/workout_session/data/repositories/workout_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_workout_repository.dart';

void main() {
  Widget buildApp(FakeAuthRepository repository) {
    return ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider.overrideWithValue(repository),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        syncLifecycleProvider.overrideWithValue(NoopSyncLifecycle()),
      ],
      child: const CarlysApp(),
    );
  }

  testWidgets('sans session locale : splash puis écran de connexion',
      (tester) async {
    await tester.pumpWidget(buildApp(FakeAuthRepository()));

    expect(find.text('Votre entraînement, partout.'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('avec session locale : restauration directe vers l’accueil',
      (tester) async {
    await tester.pumpWidget(buildApp(FakeAuthRepository(storedSession: true)));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue, Camille !'), findsOneWidget);
    expect(find.text('camille@example.com'), findsOneWidget);
  });

  testWidgets('connexion complète depuis l’écran de connexion', (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'camille@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'MotDePasseSolide42',
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(repository.loginCalls, 1);
    expect(find.text('Bienvenue, Camille !'), findsOneWidget);
  });

  testWidgets('erreur de connexion affichée sans quitter l’écran',
      (tester) async {
    final repository = FakeAuthRepository()..failLogin = true;
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'camille@example.com',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'MauvaisMotDePasse1',
    );
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('la déconnexion ramène à l’écran de connexion', (tester) async {
    final repository = FakeAuthRepository(storedSession: true);
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    // Le bouton vit en bas de l'accueil : le rendre visible avant le tap.
    await tester.scrollUntilVisible(find.text('Se déconnecter'), 150);
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('e-mail invalide bloqué par la validation locale',
      (tester) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(buildApp(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'pas-un-email');
    await tester.enterText(find.byType(TextFormField).last, 'MotDePasse42x');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });
}
