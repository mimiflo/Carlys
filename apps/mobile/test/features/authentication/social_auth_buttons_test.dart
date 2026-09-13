import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/database/local_account_switch.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/datasources/social_sign_in.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/social_provider.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/google_glyph.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/social_auth_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_local_account_switch.dart';
import '../../support/noop_local_account_purge.dart';

/// Ce que ces tests protègent : ce que les boutons Apple et Google FONT, et
/// ce qu'ils DISENT quand ils ne peuvent rien faire.
///
/// Le jeton obtenu du fournisseur ne décide de rien : il part au serveur, qui
/// le vérifie. Ici, on éprouve le comportement visible — session ouverte,
/// silence quand la personne renonce, phrase honnête quand le fournisseur
/// n'est pas branché, message du serveur quand il refuse.
void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  Widget host({bool enabled = true}) => ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment(
          flavor: AppFlavor.development,
          apiBaseUrl: 'http://localhost:3000',
          publicWebBaseUrl: 'https://web.exemple.test',
        ),
      ),
      authRepositoryProvider.overrideWithValue(repository),
      // Ouvrir une session réclame l'appareil et purge le compte précédent :
      // inertes ici, ces boutons ne parlent pas de frontière de compte.
      localAccountPurgeProvider.overrideWithValue(NoopLocalAccountPurge()),
      localAccountSwitchProvider.overrideWithValue(FakeLocalAccountSwitch()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SocialAuthButtons(enabled: enabled)),
    ),
  );

  /// Touche un bouton et laisse la chaîne asynchrone aller jusqu'au bout :
  /// contrôleur → session → message. Deux `pump` n'y suffisent pas — la
  /// requête n'aurait même pas atteint le dépôt.
  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel('Continuer avec $label'));
    await tester.pumpAndSettle();
  }

  testWidgets('propose Apple et Google, et rien d’autre', (tester) async {
    await tester.pumpWidget(host());

    expect(find.bySemanticsLabel('Continuer avec Apple'), findsOneWidget);
    expect(find.bySemanticsLabel('Continuer avec Google'), findsOneWidget);
    expect(find.byType(GoogleGlyph), findsOneWidget);
    expect(find.text('OU'), findsOneWidget);
    // Pas de Discord, pas d'autre fournisseur : la maquette en montrait
    // trois, la demande en retient deux.
    expect(find.bySemanticsLabel(RegExp('Discord')), findsNothing);
  });

  testWidgets('le toucher ouvre VRAIMENT une session, sans rien annoncer', (
    tester,
  ) async {
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    // Le fournisseur demandé est bien celui du bouton…
    expect(repository.lastSocialProvider, SocialProvider.google);
    // …la session est ouverte (le routeur emmène ailleurs en production)…
    expect(repository.storedSession, isTrue);
    // …et rien ne s'affiche : il n'y a rien à dire quand ça marche.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('renoncer devant la feuille ne dit RIEN', (tester) async {
    repository.socialCancelled = true;
    await tester.pumpWidget(host());

    await tap(tester, 'Apple');

    expect(repository.storedSession, isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('fournisseur pas encore activé côté serveur : on le DIT', (
    tester,
  ) async {
    // 503 : le serveur n'a pas d'audience configurée pour ce fournisseur.
    repository.socialError = const ServerException(
      'peu importe',
      statusCode: 503,
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    expect(
      find.textContaining('La connexion avec Google arrive bientôt'),
      findsOneWidget,
    );
  });

  testWidgets('Apple hors iPhone : le message nomme la bonne raison', (
    tester,
  ) async {
    repository.socialError = const SocialSignInUnavailable(
      SocialProvider.apple,
      SocialSignInObstacle.plateforme,
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Apple');

    expect(
      find.textContaining('n’existe que sur iPhone et iPad'),
      findsOneWidget,
    );
  });

  testWidgets('refus du serveur : c’est SON message qu’on lit', (tester) async {
    // Le cas réel : le fournisseur n'a pas transmis d'adresse vérifiée.
    repository.socialError = const UnauthorizedException(
      'Le fournisseur n’a pas transmis d’adresse e-mail vérifiée.',
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    expect(find.textContaining('adresse e-mail vérifiée'), findsOneWidget);
  });

  testWidgets('panne réseau : un message utile, jamais une trace technique', (
    tester,
  ) async {
    repository.socialError = const NetworkException('Serveur injoignable');
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    expect(find.textContaining('n’a pas abouti'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('neutralisés pendant une soumission', (tester) async {
    await tester.pumpWidget(host(enabled: false));

    await tester.tap(
      find.bySemanticsLabel('Continuer avec Google'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repository.lastSocialProvider, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });
}
