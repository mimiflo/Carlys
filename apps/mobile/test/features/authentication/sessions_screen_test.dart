import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_session_device.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/sessions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

/// L'ÉCRAN DES APPAREILS CONNECTÉS.
///
/// C'est le geste de reprise de contrôle : voir où la session est ouverte, et
/// la fermer à distance. Il n'avait aucun test alors que le faux dépôt
/// portait déjà tout ce qu'il faut. On vérifie ici les quatre états (liste,
/// panne serveur, hors ligne, chargement implicite) ET que la révocation
/// passe bien par le dépôt : un écran qui retirerait la ligne sans appeler le
/// serveur laisserait l'appareil connecté.
void main() {
  final now = DateTime.utc(2026, 9, 7, 10);

  final thisPhone = AuthSessionDevice(
    id: 'session-courante',
    current: true,
    createdAt: now,
    lastUsedAt: now,
    deviceName: 'iPhone de Camille',
    devicePlatform: 'ios',
  );
  final otherPhone = AuthSessionDevice(
    id: 'session-autre',
    current: false,
    createdAt: now,
    lastUsedAt: now,
    deviceName: 'Pixel du bureau',
    devicePlatform: 'android',
  );

  Widget screen(FakeAuthRepository repository) => ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(theme: AppTheme.dark(), home: const SessionsScreen()),
  );

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
  }

  testWidgets('la liste montre chaque appareil, et désigne celui-ci', (
    tester,
  ) async {
    final repository = FakeAuthRepository(storedSession: true)
      ..devices = [thisPhone, otherPhone];

    await tester.pumpWidget(screen(repository));
    // Le temps du premier `build` : l'écran annonce son chargement au lieu
    // de clignoter sur une liste vide.
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('iPhone de Camille'), findsOneWidget);
    expect(find.text('Pixel du bureau'), findsOneWidget);
    // Celui qu'on tient ne se déconnecte pas d'ici : pas de croix en face.
    expect(find.text('Cet appareil'), findsOneWidget);
    expect(find.byTooltip('Déconnecter cet appareil'), findsOneWidget);
  });

  testWidgets('déconnecter un appareil passe par le serveur, puis la liste '
      'se relit', (tester) async {
    final repository = FakeAuthRepository(storedSession: true)
      ..devices = [thisPhone, otherPhone];

    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Déconnecter cet appareil'));
    await tester.pumpAndSettle();
    expect(find.text('« Pixel du bureau » devra se reconnecter.'), findsOne);
    await confirm(tester);

    expect(repository.revokeCalls, 1);
    expect(find.text('Pixel du bureau'), findsNothing);
    expect(find.text('iPhone de Camille'), findsOneWidget);
  });

  testWidgets('annuler la confirmation ne déconnecte rien', (tester) async {
    final repository = FakeAuthRepository(storedSession: true)
      ..devices = [thisPhone, otherPhone];

    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Déconnecter cet appareil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(repository.revokeCalls, 0);
    expect(find.text('Pixel du bureau'), findsOneWidget);
  });

  testWidgets('déconnecter les autres appareils ne laisse que celui-ci', (
    tester,
  ) async {
    final repository = FakeAuthRepository(storedSession: true)
      ..devices = [thisPhone, otherPhone];

    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Déconnecter tous les autres appareils'));
    await tester.pumpAndSettle();
    await confirm(tester);

    expect(repository.revokeOtherCalls, 1);
    expect(find.text('Pixel du bureau'), findsNothing);
    // Seul ici : le bouton global disparaît, il n'aurait plus rien à couper.
    expect(find.text('Déconnecter tous les autres appareils'), findsNothing);
  });

  testWidgets('seul appareil connecté : aucun bouton de révocation globale', (
    tester,
  ) async {
    final repository = FakeAuthRepository(storedSession: true)
      ..devices = [thisPhone];

    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();

    expect(find.text('Déconnecter tous les autres appareils'), findsNothing);
    expect(find.byTooltip('Déconnecter cet appareil'), findsNothing);
  });

  testWidgets('hors ligne : état d’erreur, et le réessai relit la liste', (
    tester,
  ) async {
    final repository = FakeAuthRepository(storedSession: true)
      ..devices = [thisPhone, otherPhone]
      ..sessionsFailure = const NetworkException('Serveur injoignable');

    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger les appareils'), findsOneWidget);
    expect(find.text(AppErrorState.retryConnectionMessage), findsOneWidget);

    // Le réseau revient : le bouton doit réellement rejouer la lecture.
    repository.sessionsFailure = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('iPhone de Camille'), findsOneWidget);
  });

  testWidgets('serveur en panne : état d’erreur plutôt qu’une liste vide', (
    tester,
  ) async {
    final repository = FakeAuthRepository(storedSession: true)
      ..devices = [thisPhone]
      ..sessionsFailure = const ServerException('Panne', statusCode: 500);

    await tester.pumpWidget(screen(repository));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('iPhone de Camille'), findsNothing);
  });
}
