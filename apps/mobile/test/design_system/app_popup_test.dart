import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contrast.dart';

/// LA CARTE DES POPUPS se lit, et ne déborde jamais.
///
/// Deux mesures, pas deux impressions : chaque texte posé sur la carte tient
/// AA (4,5:1) sur sa surface ET au plus fort de son halo violet, dans les
/// deux thèmes de l'application ; et aucune des trois portes ne déborde
/// quand le texte est agrandi deux fois sur un téléphone de 320 points.

/// La couleur RENDUE d'un texte : celle de son style, thème compris (un
/// libellé de bouton n'a pas de style propre, il hérite du bouton).
Color _ink(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.text(text), matching: find.byType(RichText)),
  );
  return paragraph.text.style!.color!;
}

/// Ce qui est peint SOUS le libellé d'un bouton d'action.
///
/// La couleur résolue de son `Material` ; s'il est transparent (l'action
/// principale), le dégradé posé dessous, lu aux deux bords du libellé. Un
/// dégradé linéaire à deux arrêts varie de façon monotone : ses deux
/// lectures encadrent tout ce que le libellé recouvre.
List<Color> _fillsBehind(WidgetTester tester, String label) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byType(FilledButton),
  );
  final fill = tester
      .widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      )
      .color!;
  if (fill.a == 1) return [fill];

  final painted = find
      .ancestor(of: button, matching: find.byType(DecoratedBox))
      .first;
  final gradient =
      (tester.widget<DecoratedBox>(painted).decoration as BoxDecoration)
              .gradient!
          as LinearGradient;
  expect(gradient.colors, hasLength(2));
  expect(gradient.stops, isNull);
  expect(gradient.begin, Alignment.centerLeft);
  expect(gradient.end, Alignment.centerRight);
  final box = tester.getRect(painted);
  final ink = tester.getRect(find.text(label));
  Color at(double x) => Color.lerp(
    gradient.colors.first,
    gradient.colors.last,
    ((x - box.left) / box.width).clamp(0, 1),
  )!;
  return [at(ink.left), at(ink.right)];
}

late BuildContext _screen;

Widget _app({ThemeData? theme, double textScale = 1}) => MaterialApp(
  theme: theme ?? AppTheme.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) {
        _screen = context;
        return const SizedBox.expand();
      },
    ),
  ),
);

void main() {
  group('contraste de chaque texte sur la carte', () {
    // Le pic du halo : le violet le plus dense sous un texte.
    final haloPeak = Color.alphaBlend(
      AppColors.primaryBadgeBg,
      AppColors.darkSurface,
    );

    for (final (name, theme) in [
      ('thème sombre', AppTheme.dark()),
      // La carte est sombre dans les DEUX thèmes : elle impose le sien à
      // son contenu, sans quoi le bouton fantôme prendrait le violet vif
      // du thème clair, illisible sur elle.
      ('thème clair', AppTheme.light()),
    ]) {
      testWidgets('$name : titre, message et bouton de renonciation', (
        tester,
      ) async {
        await tester.pumpWidget(_app(theme: theme));
        unawaited(
          showAppConfirm(
            _screen,
            title: 'Retirer Léa ?',
            message: 'Elle ne verra plus tes séances.',
            confirmLabel: 'Retirer',
            destructive: true,
          ),
        );
        await tester.pumpAndSettle();

        final surface = tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(AppPopupCard),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color!;
        expect(surface, AppColors.darkSurface);
        for (final text in [
          'Retirer Léa ?',
          'Elle ne verra plus tes séances.',
          'Annuler',
        ]) {
          for (final background in [surface, haloPeak]) {
            expect(
              contrast(_ink(tester, text), background),
              greaterThanOrEqualTo(4.5),
              reason: '« $text » sur $background',
            );
          }
        }
      });
    }

    for (final (name, theme) in [
      ('thème sombre', AppTheme.dark()),
      ('thème clair', AppTheme.light()),
    ]) {
      for (final destructive in [false, true]) {
        final variant = destructive ? 'destructif' : 'principal';
        testWidgets('$name : libellé du bouton $variant, sur son fond', (
          tester,
        ) async {
          // Blanc sur le rouge `danger` ne tenait que 3,76:1 : chaque
          // « Supprimer », « Retirer », « Quitter » de l'application.
          await tester.pumpWidget(_app(theme: theme));
          unawaited(
            showAppConfirm(
              _screen,
              title: 'Quitter le défi ?',
              message: 'Tes séances resteront à toi.',
              confirmLabel: 'Quitter',
              destructive: destructive,
            ),
          );
          await tester.pumpAndSettle();

          final ink = _ink(tester, 'Quitter');
          final fills = _fillsBehind(tester, 'Quitter');
          expect(fills, isNotEmpty);
          for (final fill in fills) {
            expect(
              contrast(ink, fill),
              greaterThanOrEqualTo(4.5),
              reason: '« Quitter » ($variant) sur $fill',
            );
          }
        });
      }
    }

    testWidgets('un message SEUL prend la voix du texte principal', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      AppNotices.of(_screen).show('Objectif retenu : Force.');
      await tester.pumpAndSettle();

      final ink = _ink(tester, 'Objectif retenu : Force.');
      expect(ink, AppColors.darkTextPrimary);
      expect(contrast(ink, haloPeak), greaterThanOrEqualTo(4.5));
    });
  });

  group('texte agrandi deux fois, sur 320 points de large', () {
    /// Le plus étroit des téléphones courants : 320 × 568 points.
    Future<void> pumpNarrow(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(640, 1136);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(textScale: 2));
    }

    Future<void> expectFits(WidgetTester tester) async {
      await tester.pumpAndSettle();
      // Un débordement se signale comme une exception de rendu.
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(AppPopupCard));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(320));
    }

    testWidgets('message passager avec titre et action', (tester) async {
      await pumpNarrow(tester);
      AppNotices.of(_screen).show(
        'Léa te défie : cinq séances cette semaine, avant dimanche soir.',
        title: 'Nouveau défi entre amis',
        actionLabel: 'Voir le défi',
        onAction: () {},
      );
      await expectFits(tester);
    });

    testWidgets('confirmation', (tester) async {
      await pumpNarrow(tester);
      unawaited(
        showAppConfirm(
          _screen,
          title: 'Déconnecter cet appareil ?',
          message: 'Il devra se reconnecter avec ton mot de passe.',
          confirmLabel: 'Déconnecter l’appareil',
          destructive: true,
        ),
      );
      await expectFits(tester);
    });

    testWidgets('porte générique, avec une pastille de constat', (
      tester,
    ) async {
      // La clôture d'une séance suivie d'un programme pose son constat en
      // pastille sous le message ; une pastille ne revenait pas à la ligne.
      await pumpNarrow(tester);
      unawaited(
        showAppDialog<void>(
          _screen,
          builder: (context) => AppPopupCard(
            icon: AppIcons.confirmFinish,
            title: 'Terminer la séance ?',
            message: 'Tes séries sont enregistrées et seront synchronisées.',
            content: const Center(
              child: AppPill(
                label: '12 séries sur 12 prévues',
                tone: AppPillTone.primary,
                mono: true,
              ),
            ),
            actions: [AppButton(label: 'Confirmer', onPressed: () {})],
          ),
        ),
      );
      await expectFits(tester);
    });

    testWidgets('saisie', (tester) async {
      await pumpNarrow(tester);
      unawaited(
        showAppPrompt(
          _screen,
          title: 'Exercice libre',
          hint: 'Nom de l’exercice',
          maxLength: 120,
          confirmLabel: 'Choisir',
        ),
      );
      await expectFits(tester);
    });
  });

  testWidgets('sur un grand écran, la carte ne s’étale pas', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    AppNotices.of(_screen).show('Séance enregistrée.');
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(AppPopupCard)).width,
      AppPopupCard.maxWidth,
    );
  });

  testWidgets('une erreur passe le médaillon au rouge sémantique', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    AppNotices.of(
      _screen,
    ).show('La séance n’a pas pu être lancée.', tone: AppNoticeTone.error);
    await tester.pumpAndSettle();

    final card = tester.widget<AppPopupCard>(find.byType(AppPopupCard));
    expect(card.tone, AppPopupTone.danger);
    expect(card.icon, AppIcons.noticeError);
  });
}
