import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// L'EN-TÊTE DE SECTION, au doigt, au lecteur d'écran et en texte agrandi.
///
/// Son action de fin (« Voir les 4 », « Nouveau », « Tout voir »…) faisait
/// 23 points de haut, et sa sémantique n'était pas une frontière : l'action
/// remontait jusqu'à l'élément de liste, qui absorbait la section entière —
/// activer « Récompenses » relisait douze lignes et déclenchait « Voir les
/// 4 ». Le titre, lui, n'était pas annoncé comme un titre. Et en texte ×2,
/// une action longue (« Objectif 2 345 kcal ») sortait de l'écran.
void main() {
  setUpAll(loadAppFonts);

  Widget section({
    required String titre,
    required String action,
    IconData? icone,
    VoidCallback? onTap,
  }) => MaterialApp(
    theme: AppTheme.dark(),
    home: AppDarkScaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          // Un élément de liste qui porte l'en-tête ET son contenu, comme
          // la vitrine des récompenses.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionHeader(
                title: titre,
                trailing: action,
                trailingIcon: icone,
                trailingTone: AppSectionTrailingTone.primary,
                onTrailingTap: onTap ?? () {},
              ),
              const Text('Dix séances'),
              const Text('Première semaine complète'),
            ],
          ),
        ],
      ),
    ),
  );

  testWidgets('l’action de fin est une cible de 48 points', (tester) async {
    var touches = 0;
    await tester.pumpWidget(
      section(
        titre: 'Récompenses · 4',
        action: 'Voir les 4',
        onTap: () {
          touches++;
        },
      ),
    );

    final action = find.ancestor(
      of: find.text('VOIR LES 4'),
      matching: find.byType(GestureDetector),
    );
    expect(
      tester.getSize(action.first).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
    await tester.tapAt(
      tester.getRect(action.first).topCenter + const Offset(0, 2),
    );
    expect(touches, 1);
  });

  testWidgets('l’action est un bouton à part, le titre est un titre', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var touches = 0;
    await tester.pumpWidget(
      section(
        titre: 'Récompenses · 4',
        action: 'Voir les 4',
        onTap: () {
          touches++;
        },
      ),
    );

    final bouton = tester.getSemantics(find.text('VOIR LES 4'));
    expect(bouton.label, 'VOIR LES 4');
    expect(bouton.getSemanticsData().flagsCollection.isButton, isTrue);

    final titre = tester.getSemantics(find.text('Récompenses · 4'));
    expect(titre.label, 'Récompenses · 4');
    expect(titre.getSemanticsData().flagsCollection.isHeader, isTrue);
    expect(titre.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

    // Le contenu de la section n'est pas dans le bouton.
    final contenu = tester.getSemantics(find.text('Dix séances'));
    expect(contenu.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

    tester
        .getSemantics(find.text('VOIR LES 4'))
        .owner!
        .performAction(bouton.id, SemanticsAction.tap);
    expect(touches, 1);
    semantics.dispose();
  });

  for (final (largeur, texte) in const [
    (320.0, 2.0),
    (360.0, 1.5),
    (390.0, 1.3),
  ]) {
    testWidgets('à $largeur points, texte ×$texte : l’action reste dans '
        'l’écran, et aucun mot ne se coupe', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      for (final (titre, action, icone) in const [
        ('Macros', 'Objectif 2 345 kcal', AppIcons.info),
        ('Records personnels', 'Tout voir', null),
        ('Programmes', 'Nouveau', AppIcons.add),
      ]) {
        await tester.pumpWidget(
          section(titre: titre, action: action, icone: icone),
        );
        final entete = find.byType(AppSectionHeader);
        expect(midWordBreaks(entete), isEmpty, reason: titre);
        final ecran = Offset.zero & tester.view.physicalSize / 3;
        expect(
          ecran.contains(
            tester.getRect(find.text(action.toUpperCase())).centerRight -
                const Offset(0.5, 0),
          ),
          isTrue,
          reason: '« $action » sort de l’écran',
        );
      }
    });
  }
}
