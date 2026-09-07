import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_email_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

/// LE RAPPEL D'ADRESSE NON VÉRIFIÉE.
///
/// `POST /auth/resend-verification` était livré sans aucun appelant : une
/// adresse restée non vérifiée le restait pour toujours, et avec elle la
/// seule voie de récupération du compte. Le rappel ne bloque rien, il ouvre
/// simplement la porte — et seulement quand elle est fermée.
void main() {
  const unverified = AuthUser(
    id: 'user-1',
    email: 'camille@example.com',
    displayName: 'Camille',
    emailVerified: false,
    locale: 'fr',
    timezone: 'Europe/Paris',
  );

  Widget host(FakeAuthRepository auth, AuthUser? user) => ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment(
          flavor: AppFlavor.development,
          apiBaseUrl: 'http://localhost:3000',
        ),
      ),
      authRepositoryProvider.overrideWithValue(auth),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: ProfileEmailVerification(user: user)),
    ),
  );

  testWidgets('adresse vérifiée : rien ne s’affiche', (tester) async {
    await tester.pumpWidget(host(FakeAuthRepository(), fakeUser));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail non vérifiée'), findsNothing);
  });

  testWidgets('profil pas encore chargé : rien ne s’affiche', (tester) async {
    await tester.pumpWidget(host(FakeAuthRepository(), null));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail non vérifiée'), findsNothing);
  });

  testWidgets('adresse non vérifiée : le rappel nomme l’adresse', (
    tester,
  ) async {
    await tester.pumpWidget(host(FakeAuthRepository(), unverified));
    await tester.pumpAndSettle();

    expect(find.text('Adresse e-mail non vérifiée'), findsOneWidget);
    expect(find.textContaining('camille@example.com'), findsOneWidget);
    expect(find.text('Renvoyer l’e-mail'), findsOneWidget);
  });

  testWidgets('renvoyer : le serveur est appelé une fois, et on confirme', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(host(auth, unverified));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Renvoyer l’e-mail'));
    await tester.pumpAndSettle();

    expect(auth.resendVerificationCalls, 1);
    expect(find.textContaining('C’est envoyé'), findsOneWidget);
    // Le bouton disparaît : rien à gagner à renvoyer trois fois de suite,
    // et le serveur limite déjà la cadence.
    expect(find.text('Renvoyer l’e-mail'), findsNothing);
  });

  testWidgets('hors ligne : l’échec est dit, et l’envoi reste proposé', (
    tester,
  ) async {
    final auth = FakeAuthRepository()
      ..accountFailure = const NetworkException('Serveur injoignable');
    await tester.pumpWidget(host(auth, unverified));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Renvoyer l’e-mail'));
    await tester.pumpAndSettle();

    expect(
      find.text('Connexion impossible. Vérifie ton accès Internet.'),
      findsOneWidget,
    );
    expect(find.text('Renvoyer l’e-mail'), findsOneWidget);
  });
}
