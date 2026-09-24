import 'dart:async';

import 'package:carlys_mobile/design_system/components/app_popup_layout.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// LES MESSAGES PASSAGERS : une carte au milieu de l'écran, au thème de
/// l'application, qui se ferme d'elle-même (demande du 24 septembre 2026).
///
/// Chaque règle de `AppNotices` a son test : une seule à la fois, la
/// fermeture au toucher et au minuteur, l'exception d'accessibilité, et le
/// motif qui compte le plus pour les écrans : capturer le messager AVANT
/// une attente, puis afficher après que le `context` d'origine a disparu.

/// Le contexte d'un écran nu, récupéré pour appeler l'API comme un écran.
late BuildContext _screen;

Widget _app({Widget? home}) => MaterialApp(
  theme: AppTheme.dark(),
  home:
      home ??
      Scaffold(
        body: Builder(
          builder: (context) {
            _screen = context;
            return const Center(child: Text('Écran'));
          },
        ),
      ),
);

Future<void> _show(
  WidgetTester tester,
  String message, {
  String? title,
  String? actionLabel,
  VoidCallback? onAction,
}) async {
  AppNotices.of(
    _screen,
  ).show(message, title: title, actionLabel: actionLabel, onAction: onAction);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la popup se pose AU MILIEU de l’écran', (tester) async {
    await tester.pumpWidget(_app());
    await _show(tester, 'Mesure enregistrée.', title: 'C’est noté');

    final card = tester.getCenter(find.byType(AppPopupCard));
    final screen = tester.getCenter(find.byType(Scaffold));
    expect((card - screen).distance, lessThan(1));
    expect(find.text('C’est noté'), findsOneWidget);
    expect(find.text('Mesure enregistrée.'), findsOneWidget);
  });

  testWidgets('une seule à la fois : la nouvelle remplace la courante', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    AppNotices.of(_screen)
      ..show('Première')
      ..show('Seconde');
    await tester.pumpAndSettle();

    expect(find.byType(AppPopupCard), findsOneWidget);
    expect(find.text('Seconde'), findsOneWidget);
    expect(find.text('Première'), findsNothing);
  });

  testWidgets('sans action, elle se ferme seule au bout de 3 secondes', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _show(tester, 'Séance enregistrée.');

    await tester.pump(
      AppNotices.displayDuration - const Duration(milliseconds: 400),
    );
    expect(find.text('Séance enregistrée.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(AppPopupCard), findsNothing);
  });

  testWidgets('avec une action, elle laisse 6 secondes pour décider', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _show(tester, 'Léa te défie.', actionLabel: 'Voir', onAction: () {});

    await tester.pump(AppNotices.displayDuration);
    expect(find.text('Léa te défie.'), findsOneWidget);

    await tester.pump(AppNotices.actionDisplayDuration);
    await tester.pumpAndSettle();
    expect(find.byType(AppPopupCard), findsNothing);
  });

  testWidgets('un toucher sur la carte la ferme', (tester) async {
    await tester.pumpWidget(_app());
    await _show(tester, 'Objectif retenu.');

    await tester.tap(find.text('Objectif retenu.'));
    await tester.pumpAndSettle();
    expect(find.byType(AppPopupCard), findsNothing);
  });

  /// Un écran qui compte les touchers qu'il reçoit.
  Widget countingScreen(void Function() onTap) => _app(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          _screen = context;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox.expand(),
          );
        },
      ),
    ),
  );

  testWidgets('un simple message ne vole pas le toucher : il traverse, et '
      'referme le message', (tester) async {
    // En pleine séance, « Série supprimée. » ne doit pas coûter un geste.
    var screenTaps = 0;
    await tester.pumpWidget(countingScreen(() => screenTaps++));
    await _show(tester, 'Série supprimée.');

    // Un coin de l'écran, loin de la carte.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(screenTaps, 1, reason: 'le toucher atteint l’écran');
    expect(find.byType(AppPopupCard), findsNothing);
  });

  testWidgets('une popup qui propose un choix pose un voile : le toucher '
      'ferme, il ne traverse pas', (tester) async {
    var screenTaps = 0;
    await tester.pumpWidget(countingScreen(() => screenTaps++));
    await _show(
      tester,
      'Léa te défie.',
      actionLabel: 'Voir le défi',
      onAction: () {},
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(AppPopupCard), findsNothing);
    expect(screenTaps, 0, reason: 'le voile ferme, il ne laisse pas passer');
  });

  testWidgets('l’action ferme la popup, puis agit ; « Plus tard » renonce', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(_app());
    await _show(
      tester,
      'Léa te défie.',
      actionLabel: 'Voir le défi',
      onAction: () => actions++,
    );

    await tester.tap(find.text('Voir le défi'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.byType(AppPopupCard), findsNothing);

    await _show(
      tester,
      'Léa te défie.',
      actionLabel: 'Voir le défi',
      onAction: () => actions++,
    );
    await tester.tap(find.text(AppNotices.laterLabel));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.byType(AppPopupCard), findsNothing);
  });

  group('navigation d’accessibilité active', () {
    setUp(() {
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        accessibleNavigation: true,
      );
    });
    tearDown(
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .clearAccessibilityFeaturesTestValue,
    );

    testWidgets('avec une action, elle attend qu’on choisisse', (tester) async {
      // Un lecteur d'écran met plus de six secondes à atteindre le bouton :
      // retirer l'action pendant qu'il y va, ce serait la lui refuser.
      await tester.pumpWidget(_app());
      await _show(
        tester,
        'Léa te défie.',
        actionLabel: 'Voir',
        onAction: () {},
      );

      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Léa te défie.'), findsOneWidget);
    });

    testWidgets('sans action, elle se ferme toujours seule', (tester) async {
      await tester.pumpWidget(_app());
      await _show(tester, 'Séance enregistrée.');

      await tester.pump(AppNotices.displayDuration);
      await tester.pumpAndSettle();
      expect(find.byType(AppPopupCard), findsNothing);
    });
  });

  testWidgets('capturée AVANT une attente, elle s’affiche après la '
      'disparition du contexte d’origine', (tester) async {
    // Le motif de tous les gestes qui referment une feuille : le messager se
    // prend dans la feuille, la feuille se ferme, le geste rend la main
    // ensuite — et c'est seulement là qu'on sait quoi dire.
    final saved = Completer<void>();
    late BuildContext sheet;
    await tester.pumpWidget(_app());
    unawaited(
      showAppSheet<void>(
        _screen,
        builder: (context) {
          sheet = context;
          return AppButton(
            label: 'Enregistrer',
            onPressed: () async {
              final notices = AppNotices.of(context);
              Navigator.of(context).pop();
              await saved.future;
              notices.show('Mesure enregistrée.');
            },
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(sheet.mounted, isFalse, reason: 'la feuille est bien partie');

    saved.complete();
    await tester.pumpAndSettle();
    expect(find.text('Mesure enregistrée.'), findsOneWidget);
  });

  testWidgets('demandée PENDANT une construction, elle attend la fin de '
      'l’image', (tester) async {
    // Un écouteur de fournisseur peut se déclencher en plein rendu : poser
    // l'entrée d'overlay à cet instant reconstruirait l'overlay au milieu
    // d'une autre construction.
    var shown = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            if (!shown) {
              shown = true;
              AppNotices.of(context).show('Pendant le rendu.');
            }
            return const SizedBox.expand();
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('Pendant le rendu.'), findsOneWidget);
  });

  testWidgets('elle s’affiche PAR-DESSUS une feuille ouverte', (tester) async {
    await tester.pumpWidget(_app());
    unawaited(
      showAppSheet<void>(
        _screen,
        builder: (_) => const SizedBox(height: 400, child: Text('Feuille')),
      ),
    );
    await tester.pumpAndSettle();
    await _show(tester, 'Choisis au moins un ami à défier.');

    // Touchable, donc au-dessus : la feuille ne l'a pas recouverte.
    await tester.tap(find.text('Choisis au moins un ami à défier.'));
    await tester.pumpAndSettle();
    expect(find.byType(AppPopupCard), findsNothing);
    expect(find.text('Feuille'), findsOneWidget);
  });

  testWidgets('annoncée aux lecteurs d’écran, dans son propre nœud', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await _show(tester, 'Mesure enregistrée.', title: 'C’est noté');

    final node = tester.getSemantics(find.byType(AppPopupCard));
    expect(node, isSemantics(isLiveRegion: true, hasDismissAction: true));
    expect(node.label, contains('C’est noté'));
    expect(node.label, contains('Mesure enregistrée.'));
    semantics.dispose();
  });

  testWidgets('le retour arrière ferme la popup, pas l’écran', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) {
            _screen = context;
            return const Scaffold(body: Text('Accueil'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    );
    await _show(tester, 'Léa te défie.', actionLabel: 'Voir', onAction: () {});

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.byType(AppPopupCard), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
  });

  group('animations', () {
    Iterable<double> opacities(WidgetTester tester) => tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: find.byType(AppPopupCard),
            matching: find.byType(FadeTransition),
          ),
        )
        .map((fade) => fade.opacity.value);

    testWidgets('elle apparaît en fondu, depuis une échelle réduite', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      AppNotices.of(_screen).show('Séance enregistrée.');
      await tester.pump();

      expect(opacities(tester).any((value) => value < 1), isTrue);
      final scale = tester.widget<ScaleTransition>(
        find.ancestor(
          of: find.byType(AppPopupCard),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scale.scale.value, AppPopupTransition.enterScale);
    });

    testWidgets('réduites par le système : rien ne bouge', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app());
      AppNotices.of(_screen).show('Séance enregistrée.');
      await tester.pump();

      // Entière dès la première image : aucune opacité partielle, aucun
      // zoom.
      expect(opacities(tester), everyElement(1));
      expect(
        find.ancestor(
          of: find.byType(AppPopupCard),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('une popup encore affichée à la fin ne laisse aucune '
      'minuterie derrière elle', (tester) async {
    // Le minuteur vit dans l'état de la popup : démonter l'application
    // l'éteint. Sans quoi ce test échouerait sur « A Timer is still
    // pending » au démontage.
    await tester.pumpWidget(_app());
    await _show(tester, 'Séance enregistrée.');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
