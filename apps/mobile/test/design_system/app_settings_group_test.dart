import 'dart:ui' show Tristate;

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// LES LIGNES DE RÉGLAGE, au lecteur d'écran et en texte agrandi.
///
/// Deux défauts relevés par l'audit de septembre 2026 :
/// - chaque bascule s'annonçait « commutateur, activé » SANS NOM — son
///   libellé partait dans un nœud voisin ;
/// - une valeur de fin non flexible (« Prendre du muscle ») écrasait le
///   libellé jusqu'à une lettre par ligne en texte ×2, et « Fréquence » se
///   coupait en son milieu dès ×1,3.
void main() {
  setUpAll(loadAppFonts);

  final ouvertures = <String>[];
  final bascules = <String>[];

  Widget groupe() => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          AppSettingsGroup(
            label: 'Réglages',
            rows: [
              AppSettingsRow(
                icon: AppIcons.theme,
                label: 'Thème sombre',
                toggleValue: true,
                onToggle: (_) => bascules.add('Thème sombre'),
                onTap: () => ouvertures.add('Thème sombre'),
              ),
              AppSettingsRow(
                icon: AppIcons.notifications,
                label: 'Invitations à un défi',
                toggleValue: false,
                onToggle: (_) => bascules.add('Invitations à un défi'),
              ),
              AppSettingsRow(
                icon: AppIcons.spark,
                label: 'Ses interventions',
                toggleValue: true,
                onToggle: (_) => bascules.add('Ses interventions'),
              ),
              AppSettingsRow(
                icon: AppIcons.calendar,
                label: 'Fréquence',
                value: 'Hebdomadaire',
                onTap: () => ouvertures.add('Fréquence'),
              ),
              AppSettingsRow(
                icon: AppIcons.carlysProfile,
                label: 'Mon plan',
                value: 'Prendre du muscle',
                onTap: () => ouvertures.add('Mon plan'),
              ),
              AppSettingsRow(
                icon: AppIcons.progress,
                label: 'Repos entre séries',
                value: '2:00',
                valueIsMono: true,
                onTap: () => ouvertures.add('Repos'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  setUp(() {
    ouvertures.clear();
    bascules.clear();
  });

  Iterable<SemanticsNode> noeuds(WidgetTester tester) sync* {
    var racine = tester.getSemantics(find.byType(AppSettingsGroup));
    while (racine.parent != null) {
      racine = racine.parent!;
    }
    final pile = [racine];
    while (pile.isNotEmpty) {
      final noeud = pile.removeLast();
      yield noeud;
      noeud.visitChildren((enfant) {
        pile.add(enfant);
        return true;
      });
    }
  }

  List<SemanticsNode> interrupteurs(WidgetTester tester) => [
    for (final noeud in noeuds(tester))
      if (noeud.getSemanticsData().flagsCollection.isToggled != Tristate.none)
        noeud,
  ];

  testWidgets('chaque bascule porte le nom de sa ligne', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(groupe());

    expect(
      [for (final noeud in interrupteurs(tester)) noeud.label],
      unorderedEquals([
        'Thème sombre',
        'Invitations à un défi',
        'Ses interventions',
      ]),
    );
    semantics.dispose();
  });

  testWidgets('la bascule bascule, la ligne ouvre : deux gestes distincts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(groupe());
    final owner = tester.getSemantics(find.byType(AppSettingsGroup)).owner!;

    final bascule = interrupteurs(
      tester,
    ).firstWhere((noeud) => noeud.label == 'Thème sombre');
    owner.performAction(bascule.id, SemanticsAction.tap);
    await tester.pump();
    expect(bascules, ['Thème sombre']);
    expect(ouvertures, isEmpty);

    final ligne = noeuds(tester).firstWhere(
      (noeud) =>
          noeud.label == 'Thème sombre' &&
          noeud.getSemanticsData().flagsCollection.isToggled == Tristate.none,
    );
    expect(ligne.getSemanticsData().flagsCollection.isButton, isTrue);
    owner.performAction(ligne.id, SemanticsAction.tap);
    await tester.pump();
    expect(ouvertures, ['Thème sombre']);

    // Sans geste d'ouverture, la ligne entière est l'interrupteur.
    final invitations = interrupteurs(
      tester,
    ).firstWhere((noeud) => noeud.label == 'Invitations à un défi');
    owner.performAction(invitations.id, SemanticsAction.tap);
    await tester.pump();
    expect(bascules, ['Thème sombre', 'Invitations à un défi']);
    semantics.dispose();
  });

  for (final (largeur, texte) in const [
    (320.0, 2.0),
    (360.0, 1.5),
    (360.0, 1.3),
    (390.0, 2.0),
  ]) {
    testWidgets('à $largeur points, texte ×$texte : aucun libellé écrasé, '
        'coupé dans un mot ni tronqué', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(groupe());

      final zone = find.byType(AppSettingsGroup);
      expect(midWordBreaks(zone), isEmpty);
      expect(truncatedTexts(zone), isEmpty);
      // Le libellé garde de quoi s'écrire en mots, pas en lettres.
      for (final libelle in ['Mon plan', 'Fréquence', 'Ses interventions']) {
        expect(
          tester.getSize(find.text(libelle)).width,
          greaterThan(60),
          reason: libelle,
        );
      }
    });
  }
}
