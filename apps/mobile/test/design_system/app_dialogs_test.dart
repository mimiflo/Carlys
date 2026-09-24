import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// LES POPUPS QUI ATTENDENT UNE RÉPONSE : confirmer un geste, saisir un nom.
///
/// Ce qui compte ici est ce que rend la popup, dans CHAQUE façon de la
/// quitter : un geste qui supprime ne doit partir que d'un « oui » explicite,
/// jamais d'un toucher à côté ni d'un retour arrière.

late BuildContext _screen;

Widget _app() => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: Builder(
      builder: (context) {
        _screen = context;
        return const Center(child: Text('Écran'));
      },
    ),
  ),
);

void main() {
  group('showAppConfirm', () {
    Future<Future<bool>> open(
      WidgetTester tester, {
      bool destructive = false,
    }) async {
      await tester.pumpWidget(_app());
      final answer = showAppConfirm(
        _screen,
        title: 'Supprimer la mesure ?',
        message: 'Elle disparaîtra de ta courbe.',
        confirmLabel: 'Supprimer',
        destructive: destructive,
      );
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('rend VRAI quand on confirme', (tester) async {
      final answer = await open(tester);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(await answer, isTrue);
      expect(find.byType(AppPopupCard), findsNothing);
    });

    testWidgets('rend FAUX quand on renonce', (tester) async {
      final answer = await open(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
    });

    testWidgets('rend FAUX quand on touche le voile', (tester) async {
      final answer = await open(tester);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
      expect(find.byType(AppPopupCard), findsNothing);
    });

    testWidgets('rend FAUX quand on fait retour', (tester) async {
      final answer = await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await answer, isFalse);
      expect(find.text('Écran'), findsOneWidget);
    });

    testWidgets('au milieu de l’écran, titre et message centrés', (
      tester,
    ) async {
      await open(tester);
      final card = tester.getCenter(find.byType(AppPopupCard));
      final screen = tester.getCenter(find.byType(Scaffold));
      expect((card - screen).distance, lessThan(1));
      for (final text in [
        'Supprimer la mesure ?',
        'Elle disparaîtra de ta courbe.',
      ]) {
        expect(
          tester.widget<Text>(find.text(text)).textAlign,
          TextAlign.center,
        );
      }
    });

    testWidgets('le nom de la popup couvre la carte, et laisse le voile au '
        'doigt', (tester) async {
      // À l'exploration tactile (TalkBack), le toucher tombe sur le nœud
      // étiqueté le plus profond qui contient le doigt. Posé sur tout
      // l'écran, le nœud « Boîte de dialogue » recouvrait le voile « Fermer »
      // : un toucher à côté de la carte ne trouvait plus que lui, muet.
      final semantics = tester.ensureSemantics();
      await open(tester);

      final node = tester.getSemantics(
        find.ancestor(
          of: find.byType(AppPopupCard),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.namesRoute == true,
          ),
        ),
      );
      expect(node.label, const DefaultMaterialLocalizations().dialogLabel);
      expect(node.rect.size, tester.getSize(find.byType(AppPopupCard)));
      semantics.dispose();
    });

    testWidgets('elle part plus vite qu’elle n’arrive, comme un message '
        'passager', (tester) async {
      await open(tester);
      final route = ModalRoute.of(tester.element(find.byType(AppPopupCard)))!;
      expect(route.transitionDuration, AppMotion.normal);
      expect(route.reverseTransitionDuration, AppMotion.fast);

      // Une image pour lancer le départ, sa durée, puis une image pour
      // retirer la route : 166 ms, quand l'arrivée en prend 250.
      await tester.tap(find.text('Annuler'));
      await tester.pump();
      await tester.pump(AppMotion.fast);
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(AppPopupCard), findsNothing);
    });

    testWidgets('un geste qui supprime a son bouton ROUGE, pas son médaillon', (
      tester,
    ) async {
      await open(tester, destructive: true);
      final confirm = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Supprimer'),
      );
      expect(confirm.variant, AppButtonVariant.destructive);
      final card = tester.widget<AppPopupCard>(find.byType(AppPopupCard));
      expect(card.tone, AppPopupTone.brand);
      expect(card.icon, AppIcons.confirmDelete);
    });
  });

  group('showAppPrompt', () {
    Future<Future<String?>> open(
      WidgetTester tester, {
      String? Function(String value)? validator,
      String initialValue = '',
    }) async {
      await tester.pumpWidget(_app());
      final answer = showAppPrompt(
        _screen,
        title: 'Activité libre',
        hint: 'Course, vélo, yoga…',
        maxLength: 12,
        initialValue: initialValue,
        validator: validator,
      );
      await tester.pumpAndSettle();
      return answer;
    }

    AppButton confirm(WidgetTester tester) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Valider'));

    testWidgets('rend la saisie, sans ses espaces de bord', (tester) async {
      final answer = await open(tester);
      await tester.enterText(find.byType(TextField), '  Yoga  ');
      await tester.pump();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(await answer, 'Yoga');
    });

    testWidgets('le champ a le focus dès l’ouverture, et « OK » valide', (
      tester,
    ) async {
      final answer = await open(tester);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);

      await tester.enterText(find.byType(TextField), 'Vélo');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(await answer, 'Vélo');
    });

    testWidgets('un champ vide ne se valide pas', (tester) async {
      final answer = await open(tester);
      expect(confirm(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(confirm(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Natation');
      await tester.pump();
      expect(confirm(tester).onPressed, isNotNull);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(await answer, isNull);
    });

    testWidgets('renoncer, toucher le voile ou faire retour rend null', (
      tester,
    ) async {
      var answer = await open(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(await answer, isNull);

      answer = await open(tester);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(await answer, isNull);

      answer = await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await answer, isNull);
    });

    testWidgets('la règle du geste refuse, et le dit sous le champ', (
      tester,
    ) async {
      final answer = await open(
        tester,
        validator: (value) => value == 'Repos' ? 'Ce nom est réservé.' : null,
      );
      await tester.enterText(find.byType(TextField), 'Repos');
      await tester.pump();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(find.text('Ce nom est réservé.'), findsOneWidget);
      expect(find.byType(AppPopupCard), findsOneWidget);

      // Corriger efface l'erreur, et la saisie part.
      await tester.enterText(find.byType(TextField), 'Récupération');
      await tester.pump();
      expect(find.text('Ce nom est réservé.'), findsNothing);
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(await answer, 'Récupération');
    });

    testWidgets('la saisie part du texte initial, bornée à sa longueur', (
      tester,
    ) async {
      final answer = await open(tester, initialValue: 'Course');
      expect(find.text('Course'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Course à pied longue');
      await tester.pump();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(await answer, 'Course à pie');
    });

    testWidgets('clavier ouvert : la carte remonte au-dessus de lui', (
      tester,
    ) async {
      // Un téléphone de 390 × 844 points, barre d'état de 48, clavier de
      // 300 : la carte doit tenir dans les 496 points qui restent.
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      tester.view.padding = const FakeViewPadding(top: 144);
      addTearDown(tester.view.reset);
      unawaited(await open(tester));

      final card = tester.getRect(find.byType(AppPopupCard));
      expect(card.bottom, lessThanOrEqualTo(844 - 300));
      expect(card.top, greaterThanOrEqualTo(48));
    });
  });

  testWidgets('showAppDialog : la même coquille pour une forme libre', (
    tester,
  ) async {
    // La clôture de séance ajoute un constat (« 9 séries sur 12 ») sous son
    // message : ni une question nue, ni une saisie.
    await tester.pumpWidget(_app());
    final answer = showAppDialog<String>(
      _screen,
      builder: (context) => AppPopupCard(
        icon: AppIcons.confirmQuestion,
        title: 'Terminer la séance ?',
        message: 'Tes séries sont enregistrées.',
        content: const AppPill(label: '9 séries sur 12'),
        actions: [
          AppButton(
            label: 'Terminer',
            onPressed: () => Navigator.of(context).pop('fin'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('9 séries sur 12'), findsOneWidget);

    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(await answer, 'fin');
  });
}
