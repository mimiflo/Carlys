import 'dart:async';

import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/database/local_account_purge.dart';
import 'package:carlys_mobile/core/database/local_account_switch.dart';
import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/core/utilities/external_links.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/change_password_screen.dart';
import 'package:carlys_mobile/features/authentication/presentation/screens/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_local_account_switch.dart';
import '../../support/noop_local_account_purge.dart';

/// LES DEUX GESTES DE COMPTE, exigés par les magasins d'applications autant
/// que par le règlement : changer son mot de passe, et supprimer son compte
/// SANS écrire au support.
///
/// Ce qui est vérifié ici : que le mot de passe saisi part bien au dépôt
/// (donc au serveur), qu'un refus est montré au lieu d'être avalé, et que la
/// suppression n'est jamais « réussie » côté application quand le serveur ne
/// l'a pas acceptée — un écran qui déconnecterait sur un mauvais mot de passe
/// laisserait croire à une suppression qui n'a pas eu lieu.
/// Purge dont on tient la porte : elle reproduit le temps réel que prend
/// l'effacement local (Drift, préférences, trousseau) — la fenêtre pendant
/// laquelle l'écran est encore à l'écran alors que le compte n'existe plus.
class _GatedPurge implements LocalAccountPurge {
  _GatedPurge(this.gate);

  final Completer<void> gate;
  int runs = 0;

  @override
  Future<void> run() async {
    runs++;
    await gate.future;
  }
}

void main() {
  late FakeAuthRepository auth;
  late NoopLocalAccountPurge purge;
  late List<Uri> openedLinks;

  setUp(() {
    auth = FakeAuthRepository(storedSession: true);
    purge = NoopLocalAccountPurge();
    openedLinks = <Uri>[];
  });

  Widget host(Widget screen, {LocalAccountPurge? localPurge}) => ProviderScope(
    overrides: [
      appEnvironmentProvider.overrideWithValue(
        const AppEnvironment(
          flavor: AppFlavor.development,
          apiBaseUrl: 'http://localhost:3000',
          publicWebBaseUrl: 'https://web.exemple.test',
        ),
      ),
      authRepositoryProvider.overrideWithValue(auth),
      localAccountPurgeProvider.overrideWithValue(localPurge ?? purge),
      // Restaurer une session réclame l'appareil : inerte ici, ces écrans
      // ne parlent pas de frontière de compte.
      localAccountSwitchProvider.overrideWithValue(FakeLocalAccountSwitch()),
      // Le récapitulatif de suppression renvoie à la politique de
      // confidentialité : aucun navigateur ne s'ouvre depuis un test.
      externalLinkOpenerProvider.overrideWithValue((url) async {
        openedLinks.add(url);
        return true;
      }),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: screen),
  );

  /// L'écran de suppression n'a qu'un champ : le mot de passe de
  /// confirmation. Pas besoin de le distinguer d'un autre.
  Future<void> typePassword(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextFormField), value);
    await tester.pumpAndSettle();
  }

  group('changer son mot de passe', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(host(const ChangePasswordScreen()));
      await tester.pumpAndSettle();
    }

    /// Les trois champs sont des `AppPasswordField` : on les remplit par leur
    /// position, la seule chose stable quand trois champs se ressemblent.
    Future<void> typeAll(
      WidgetTester tester, {
      required String current,
      required String next,
      String? confirmation,
    }) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), current);
      await tester.enterText(fields.at(1), next);
      await tester.enterText(fields.at(2), confirmation ?? next);
      await tester.pumpAndSettle();
    }

    testWidgets('l’écran prévient AVANT que les autres appareils tombent', (
      tester,
    ) async {
      await open(tester);
      expect(
        find.textContaining('autres appareils seront déconnectés'),
        findsOneWidget,
      );
    });

    testWidgets('succès : le couple part au dépôt, et l’écran le confirme', (
      tester,
    ) async {
      await open(tester);
      await typeAll(
        tester,
        current: 'ancien-mot-de-passe',
        next: 'nouveau-mot-de-passe',
      );
      await tester.tap(find.text('Changer mon mot de passe').last);
      await tester.pumpAndSettle();

      expect(auth.passwordChanges, [
        ('ancien-mot-de-passe', 'nouveau-mot-de-passe'),
      ]);
      expect(find.text('C’est fait'), findsOneWidget);
      expect(
        find.textContaining('autres appareils ont été déconnectés'),
        findsOneWidget,
      );
    });

    testWidgets('mauvais mot de passe : le refus du serveur est affiché', (
      tester,
    ) async {
      auth.accountFailure = const UnauthorizedException(
        'Mot de passe incorrect.',
      );
      await open(tester);
      await typeAll(tester, current: 'faux', next: 'nouveau-mot-de-passe');
      await tester.tap(find.text('Changer mon mot de passe').last);
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
      expect(find.text('C’est fait'), findsNothing);
    });

    testWidgets('hors ligne : on parle de réseau, pas de mot de passe', (
      tester,
    ) async {
      auth.accountFailure = const NetworkException('Serveur injoignable');
      await open(tester);
      await typeAll(tester, current: 'ancien', next: 'nouveau-mot-de-passe');
      await tester.tap(find.text('Changer mon mot de passe').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Connexion impossible. Vérifie ton accès Internet.'),
        findsOneWidget,
      );
      expect(find.text('C’est fait'), findsNothing);
    });

    testWidgets('confirmation qui diffère : rien ne part', (tester) async {
      await open(tester);
      await typeAll(
        tester,
        current: 'ancien',
        next: 'nouveau-mot-de-passe',
        confirmation: 'autre-mot-de-passe',
      );
      await tester.tap(find.text('Changer mon mot de passe').last);
      await tester.pumpAndSettle();

      expect(auth.passwordChanges, isEmpty);
      expect(find.text('Les deux mots de passe diffèrent.'), findsOneWidget);
    });

    testWidgets('nouveau identique à l’ancien : refusé sur l’appareil', (
      tester,
    ) async {
      await open(tester);
      await typeAll(tester, current: 'mot-de-passe-actuel', next: 'x');
      // `x` échoue déjà sur la longueur : on retape le même que l'actuel.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'mot-de-passe-actuel');
      await tester.enterText(fields.at(2), 'mot-de-passe-actuel');
      await tester.tap(find.text('Changer mon mot de passe').last);
      await tester.pumpAndSettle();

      expect(auth.passwordChanges, isEmpty);
      expect(
        find.text('Choisis un mot de passe différent de l’actuel.'),
        findsOneWidget,
      );
    });
  });

  group('supprimer son compte', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(host(const DeleteAccountScreen()));
      await tester.pumpAndSettle();
    }

    /// L'écran explique longuement avant de demander : sur la fenêtre de
    /// test (800 × 600) le bouton est sous la ligne de flottaison, comme il
    /// le sera sur un petit téléphone. On le fait venir, puis on appuie.
    /// [extrait], lu sous le titre de bloc [titre] : une phrase juste prise
    /// seule devient fausse sous « Effacé tout de suite » si le serveur la
    /// garde.
    Finder sous(String titre, String extrait) => find.descendant(
      of: find
          .ancestor(of: find.text(titre), matching: find.byType(AppCard))
          .first,
      matching: find.textContaining(extrait),
    );

    Future<void> submit(WidgetTester tester) async {
      final button = find.text('Supprimer définitivement');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('l’écran dit ce qui part et ce qui reste', (tester) async {
      await open(tester);

      expect(find.text('Effacé tout de suite'), findsOneWidget);
      expect(find.text('Ce qui reste'), findsOneWidget);
      expect(find.textContaining('L’adresse redevient libre'), findsOneWidget);
      expect(find.textContaining('journal de sécurité'), findsOneWidget);
    });

    testWidgets('« ce qui reste » dit ce que la politique annonce, pas mieux', (
      tester,
    ) async {
      // Le serveur PSEUDONYMISE : la ligne User, son identifiant et les clés
      // étrangères survivent, et l'audit garde `userId` avec l'adresse IP.
      // Promettre que « plus rien ne les relie à toi » était donc une
      // promesse que personne ne tient.
      await open(tester);

      expect(
        find.textContaining('ton identité en est retirée'),
        findsOneWidget,
      );
      expect(find.textContaining('plus rien ne les relie'), findsNothing);
      // La section 6 de la politique : 30 jours, puis l'effacement définitif
      // que `deleted-accounts-purge` exécute chaque jour.
      expect(find.textContaining('restent en base 30 jours'), findsOneWidget);
      expect(
        find.textContaining('tout est effacé définitivement'),
        findsOneWidget,
      );
      // La suppression efface l'adresse qui permettrait de retrouver le
      // compte : la demande vient donc AVANT, et c'est Carlys qui supprime
      // puis efface (`deleted-accounts-purge --compte-actif`), comme le dit
      // la politique. Plus « puis supprime-le » : un geste qu'on fait pour
      // la personne.
      expect(
        sous('Ce qui reste', 'écris-nous avant de supprimer ton compte'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'on le supprime et on l’efface tout de suite pour toi',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('puis supprime-le'), findsNothing);
    });

    testWidgets('l’écran dit ce que devient l’abonnement', (tester) async {
      // Le serveur résilie l'abonnement Stripe AVANT de supprimer le compte,
      // et refuse (503) s'il n'y arrive pas. Un abonnement pris dans un
      // magasin d'applications, lui, ne se résilie que dans le magasin.
      await open(tester);

      // Résilié n'est pas effacé : l'abonnement reste en base 30 jours,
      // comme la politique le compte. Il se lit donc sous « Ce qui reste ».
      expect(
        sous(
          'Ce qui reste',
          'chez Stripe : il est résilié avant la suppression',
        ),
        findsOneWidget,
      );
      expect(sous('Effacé tout de suite', 'Stripe'), findsNothing);
      expect(
        find.textContaining('Play Store ou l’App Store : Carlys ne peut pas'),
        findsOneWidget,
      );
      // L'ancienne consigne disait l'inverse : « la suppression ne le
      // résilie pas, résilie-le d'abord avec Gérer mon abonnement ».
      expect(
        find.textContaining('la suppression ne le résilie pas'),
        findsNothing,
      );
      expect(find.textContaining('Gérer mon abonnement'), findsNothing);
    });

    testWidgets('l’écran dit qu’on sort tout de suite de la communauté', (
      tester,
    ) async {
      // Le serveur retire la personne de sa ligue, de ses défis entre amis et
      // du fil des encouragements DANS la transaction de suppression.
      await open(tester);

      expect(
        find.textContaining(
          'Ta ligue, tes défis entre amis et le fil des encouragements : tu '
          'en sors tout de suite.',
        ),
        findsOneWidget,
      );
      // Le nom part, pas le score : la ligne de la semaine reste pour que
      // les rangs des autres ne bougent pas. Sous « Effacé tout de suite »,
      // le taire serait promettre un effacement que le serveur ne fait pas.
      expect(
        sous(
          'Effacé tout de suite',
          'Ton nom quitte le classement (ton score de la semaine reste '
              'compté, sans ton nom)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('la politique de confidentialité est à un geste de là', (
      tester,
    ) async {
      // Le texte y renvoie deux fois (le délai de purge, l'adresse de
      // contact) : sans ce lien, ce sont des formules, pas des instructions.
      await open(tester);
      final link = find.text('Lire la politique de confidentialité');
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(openedLinks, [Uri.parse('https://web.exemple.test/privacy')]);
    });

    testWidgets('succès : le serveur supprime, puis l’appareil oublie tout', (
      tester,
    ) async {
      await open(tester);
      await typePassword(tester, 'secret-du-jour');
      await submit(tester);

      expect(auth.deletionPasswords, ['secret-du-jour']);
      // La purge de frontière de compte tourne, et le trousseau est vidé :
      // le compte suivant sur ce téléphone ne verra rien de celui-ci.
      // On compte l'APPEL à `clearLocalSession` : `storedSession` seul ne
      // dirait pas qui l'a mis à `false`, et l'assertion passerait même si
      // l'oubli local n'avait jamais lieu.
      expect(purge.runs, 1);
      expect(auth.clearLocalSessionCalls, 1);
      expect(auth.storedSession, isFalse);
    });

    testWidgets('pendant l’oubli local, le bouton reste inerte', (
      tester,
    ) async {
      // Le compte est déjà détruit côté serveur : republier le succès avant
      // la fin de la purge réactivait le bouton rouge, et un second appui
      // relançait `deleteAccount` sur un compte qui n'existe plus.
      final gate = Completer<void>();
      final slow = _GatedPurge(gate);
      await tester.pumpWidget(
        host(const DeleteAccountScreen(), localPurge: slow),
      );
      await tester.pumpAndSettle();
      await typePassword(tester, 'secret');

      // Le bouton est cherché par son TYPE : en chargement il n'affiche plus
      // son libellé, seulement l'indicateur.
      final button = find.byType(AppButton);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      // Le bouton tourne tant que la purge est suspendue : `pumpAndSettle`
      // ne convergerait jamais, on avance donc frame par frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.deletionPasswords, ['secret']);
      expect(slow.runs, 1);
      expect(find.text('Supprimer définitivement'), findsNothing);

      // La purge tourne encore : on tape de nouveau, exactement comme un
      // doigt impatient le ferait.
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 50));
      expect(auth.deletionPasswords, ['secret']);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('trousseau en panne : on bascule quand même vers la '
        'connexion', (tester) async {
      // Le compte n'existe PLUS côté serveur. Une exception du trousseau
      // s'échappait d'un `submit()` appelé sans attendre : erreur asynchrone
      // non capturée, écran figé, jetons toujours sur l'appareil.
      auth.clearLocalSessionFailure = StateError('trousseau verrouillé');
      await tester.pumpWidget(host(const DeleteAccountScreen()));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(DeleteAccountScreen));
      final container = ProviderScope.containerOf(element);
      await container.read(authControllerProvider.notifier).restore();

      await typePassword(tester, 'secret');
      await submit(tester);

      expect(auth.clearLocalSessionCalls, 1);
      expect(purge.runs, 1);
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mauvais mot de passe : rien n’est supprimé, rien n’est '
        'purgé', (tester) async {
      auth.accountFailure = const UnauthorizedException(
        'Mot de passe incorrect.',
      );
      await open(tester);
      await typePassword(tester, 'faux');
      await submit(tester);

      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
      expect(purge.runs, 0);
      expect(auth.storedSession, isTrue);
    });

    testWidgets('abonnement non arrêté (503) : la phrase du serveur, et le '
        'compte reste', (tester) async {
      auth.accountFailure = const ServerException(
        "On n'a pas pu arrêter ton abonnement, réessaie dans un instant ; "
        "ton compte n'est pas supprimé.",
        statusCode: 503,
        fromApi: true,
      );
      await open(tester);
      await typePassword(tester, 'secret');
      await submit(tester);

      // « Le serveur est momentanément indisponible. » taisait l'essentiel :
      // rien n'est supprimé, et réessayer suffit.
      expect(
        find.text(
          'On n’a pas pu arrêter ton abonnement, réessaie dans un instant ; '
          'ton compte n’est pas supprimé.',
        ),
        findsOneWidget,
      );
      expect(purge.runs, 0);
      expect(auth.storedSession, isTrue);
      // Le bouton rouge reste là : la personne peut réessayer.
      expect(find.text('Supprimer définitivement'), findsOneWidget);
    });

    testWidgets('un 503 masqué par l’API reste une panne générique', (
      tester,
    ) async {
      auth.accountFailure = const ServerException(
        'Une erreur interne est survenue.',
        statusCode: 503,
        fromApi: true,
      );
      await open(tester);
      await typePassword(tester, 'secret');
      await submit(tester);

      expect(
        find.text('Le serveur est momentanément indisponible.'),
        findsOneWidget,
      );
      expect(purge.runs, 0);
    });

    testWidgets('abonnement de magasin encore actif : la popup le dit, '
        'par-dessus l’écran de connexion', (tester) async {
      auth.storeSubscriptionStillActive = true;
      // Comme le routeur : dès que le compte est oublié, l'écran de
      // suppression est DÉMONTÉ au milieu de `submit`, avant que la réponse
      // du serveur n'ait été dite.
      await tester.pumpWidget(
        host(
          Consumer(
            builder: (context, ref, _) =>
                ref.watch(authControllerProvider) is AuthUnauthenticated
                ? const Text('Écran de connexion')
                : const DeleteAccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeleteAccountScreen)),
      );
      await container.read(authControllerProvider.notifier).restore();
      await typePassword(tester, 'secret');
      await submit(tester);

      expect(find.byType(DeleteAccountScreen), findsNothing);
      expect(find.text('Écran de connexion'), findsOneWidget);
      expect(purge.runs, 1);
      expect(find.byType(AppPopupCard), findsOneWidget);
      expect(find.text('Compte supprimé'), findsOneWidget);
      expect(
        find.text(
          'Ton abonnement du Play Store ou de l’App Store court toujours : '
          'résilie-le là-bas.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sans abonnement de magasin : pas de popup', (tester) async {
      await open(tester);
      await typePassword(tester, 'secret');
      await submit(tester);

      expect(purge.runs, 1);
      expect(find.text('Compte supprimé'), findsNothing);
    });

    testWidgets('hors ligne : le compte reste, et on le dit', (tester) async {
      auth.accountFailure = const NetworkException('Serveur injoignable');
      await open(tester);
      await typePassword(tester, 'secret');
      await submit(tester);

      expect(
        find.text('Connexion impossible. Vérifie ton accès Internet.'),
        findsOneWidget,
      );
      expect(purge.runs, 0);
      expect(auth.storedSession, isTrue);
    });

    testWidgets('la touche « Termine » du clavier ne supprime rien', (
      tester,
    ) async {
      // La suppression exige un appui délibéré sur le bouton rouge : valider
      // le champ au clavier détruisait le compte sans ce geste-là. Le
      // changement de mot de passe, lui, garde son `onFieldSubmitted` — il
      // n'est pas irréversible.
      await open(tester);
      await typePassword(tester, 'secret');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(auth.deletionPasswords, isEmpty);
      expect(purge.runs, 0);
    });

    testWidgets('sans mot de passe : la requête ne part pas', (tester) async {
      await open(tester);
      await submit(tester);

      expect(auth.deletionPasswords, isEmpty);
      expect(find.text('Le mot de passe est requis.'), findsOneWidget);
    });
  });

  testWidgets('la suppression laisse la session fermée côté contrôleur', (
    tester,
  ) async {
    await tester.pumpWidget(host(const DeleteAccountScreen()));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(DeleteAccountScreen));
    final container = ProviderScope.containerOf(element);
    await container.read(authControllerProvider.notifier).restore();
    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

    await typePassword(tester, 'secret');
    final button = find.text('Supprimer définitivement');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });
}
