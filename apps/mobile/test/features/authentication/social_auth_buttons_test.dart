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
  late FakeLocalAccountSwitch entry;

  setUp(() {
    repository = FakeAuthRepository();
    entry = FakeLocalAccountSwitch();
  });

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
      localAccountSwitchProvider.overrideWithValue(entry),
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
    expect(find.byType(AppPopupCard), findsNothing);
  });

  testWidgets('renoncer devant la feuille ne dit RIEN', (tester) async {
    repository.socialCancelled = true;
    await tester.pumpWidget(host());

    await tap(tester, 'Apple');

    expect(repository.storedSession, isFalse);
    expect(find.byType(AppPopupCard), findsNothing);
    expect(find.textContaining('Code\u00A0:'), findsNothing);
  });

  testWidgets('fournisseur pas encore activé côté serveur : on le DIT', (
    tester,
  ) async {
    // 503 : le serveur n'a pas d'audience configurée pour ce fournisseur.
    repository.socialError = const ServerException(
      'peu importe',
      statusCode: 503,
      fromApi: true,
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    expect(
      find.textContaining('La connexion avec Google arrive bientôt'),
      findsOneWidget,
    );
    // Pas une panne : la popup garde le médaillon violet, pas le rouge.
    expect(
      tester.widget<AppPopupCard>(find.byType(AppPopupCard)).tone,
      AppPopupTone.brand,
    );
    // Mais elle porte son code : c'est quand « tout est configuré » que le
    // propriétaire en a le plus besoin.
    expect(find.text('Code\u00A0: http-503'), findsOneWidget);
  });

  testWidgets('Apple hors iPhone : le message nomme la bonne raison', (
    tester,
  ) async {
    repository.socialError = const SocialSignInUnavailable(
      SocialProvider.apple,
      SocialSignInObstacle.plateforme,
      code: 'apple-plateforme',
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Apple');

    expect(
      find.textContaining('n’existe que sur iPhone et iPad'),
      findsOneWidget,
    );
    expect(find.text('Code\u00A0: apple-plateforme'), findsOneWidget);
  });

  testWidgets('refus du serveur : c’est SON message qu’on lit', (tester) async {
    // Le cas réel, avec le texte RÉEL du serveur (social-auth.service.ts) :
    // le fournisseur n'a pas transmis d'adresse vérifiée.
    repository.socialError = const UnauthorizedException(
      'Le fournisseur n’a pas transmis d’adresse e-mail vérifiée. '
      'Connecte-toi avec ton adresse e-mail.',
      statusCode: 401,
      requestId: 'c0ffee12-3456',
      fromApi: true,
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    expect(find.textContaining('adresse e-mail vérifiée'), findsOneWidget);
    expect(
      find.text('Code\u00A0: http-401 · réf.\u00A0c0ffee12'),
      findsOneWidget,
    );
    // Un refus, lui, est un échec du geste : médaillon rouge sémantique.
    expect(
      tester.widget<AppPopupCard>(find.byType(AppPopupCard)).tone,
      AppPopupTone.danger,
    );
  });

  testWidgets('panne réseau : un message utile, jamais une trace technique', (
    tester,
  ) async {
    repository.socialError = const NetworkException(
      'Serveur injoignable',
      transport: TransportFailure.connection,
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    expect(
      find.text(
        'Le serveur Carlys est injoignable. Vérifie ta connexion, puis '
        'réessaie.',
      ),
      findsOneWidget,
    );
    expect(find.text('Code\u00A0: reseau-connexion'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('erreur serveur : la cause, le code ET la référence de requête', (
    tester,
  ) async {
    // Ce qui permet de retrouver LA ligne du journal serveur : les huit
    // premiers caractères du requestId de l'enveloppe d'erreur.
    repository.socialError = const ServerException(
      'Une erreur interne est survenue.',
      statusCode: 500,
      requestId: '1a2b3c4d-9e8f-4a5b-8c7d-0123456789ab',
      fromApi: true,
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    expect(
      find.text(
        'Le serveur Carlys n’a pas pu ouvrir ta session. Réessaie dans un '
        'instant.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Code\u00A0: http-500 · réf.\u00A01a2b3c4d'),
      findsOneWidget,
    );
    // DANS la même popup, pas une seconde carte.
    expect(find.byType(AppPopupCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppPopupCard),
        matching: find.text('Code\u00A0: http-500 · réf.\u00A01a2b3c4d'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('le lecteur d’écran DIT le code, sans l’épeler de travers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    repository.socialError = const ServerException(
      'x',
      statusCode: 502,
      requestId: '1a2b3c4d-0000',
      fromApi: true,
    );
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    // La carte fond message et code en une seule annonce (région vivante) :
    // la ligne du code y est dite sous sa forme PARLÉE, jamais écrite.
    expect(
      find.bySemanticsLabel(
        RegExp(r'\nCode : http 502, référence 1 a 2 b 3 c 4 d$'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('http-502')), findsNothing);
    semantics.dispose();
  });

  testWidgets('réclamation d’appareil refusée : appli-compte, session rendue', (
    tester,
  ) async {
    // Le point le plus traître : le SERVEUR a ouvert la session, c'est
    // l'appareil qui n'a pas pu passer à ce compte. La popup le dit, et la
    // session ne reste pas à moitié ouverte derrière elle.
    entry.failure = StateError('base verrouillée');
    await tester.pumpWidget(host());

    await tap(tester, 'Google');

    expect(find.text('Code\u00A0: appli-compte'), findsOneWidget);
    expect(find.textContaining('Ton compte n’a pas pu s’ouvrir'), findsOne);
    expect(repository.logoutCalls, 1, reason: 'session abandonnée');
    expect(repository.storedSession, isFalse);
  });

  testWidgets('le code tient à 320 points, texte agrandi deux fois', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 2
      ..physicalSize = const Size(640, 1136);
    addTearDown(tester.view.reset);
    repository.socialError = const ServerException(
      'x',
      statusCode: 503,
      requestId: '1a2b3c4d-0000',
      fromApi: true,
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: host(),
      ),
    );

    await tap(tester, 'Google');

    expect(tester.takeException(), isNull, reason: 'aucun débordement');
    final card = tester.getRect(find.byType(AppPopupCard));
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(320));
    expect(
      find.text('Code\u00A0: http-503 · réf.\u00A01a2b3c4d'),
      findsOneWidget,
    );
  });

  testWidgets('neutralisés pendant une soumission', (tester) async {
    await tester.pumpWidget(host(enabled: false));

    await tester.tap(
      find.bySemanticsLabel('Continuer avec Google'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(repository.lastSocialProvider, isNull);
    expect(find.byType(AppPopupCard), findsNothing);
  });
}
