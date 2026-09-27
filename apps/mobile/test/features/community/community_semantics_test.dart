import 'dart:ui' show Tristate;

import 'package:carlys_mobile/features/community/presentation/widgets/privacy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/community_app.dart';
import '../../support/first_run_prefs.dart';

/// L'ONGLET AMIS AU LECTEUR D'ÉCRAN.
///
/// L'onglet entier est UN élément de liste. Ni l'interrupteur de
/// confidentialité ni la carte qui le porte ne posaient de frontière
/// sémantique : son état et son geste remontaient jusqu'à l'élément, qui
/// absorbait tout le texte de l'onglet. Vingt-cinq lignes lues d'un bloc
/// comme un interrupteur — et un double-tap sur le nom d'une amie coupait le
/// partage de progression.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    // Animations réduites, comme les autres épreuves de la Communauté : les
    // scènes animées de l'accueil ne laisseraient jamais l'écran se poser.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Iterable<SemanticsNode> noeuds(WidgetTester tester) sync* {
    var racine = tester.getSemantics(find.byType(Scaffold).first);
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

  testWidgets('seule la carte de confidentialité est un interrupteur, et '
      'elle ne dit qu’elle', (tester) async {
    final semantics = tester.ensureSemantics();
    await openCommunity(tester, sampleWorldApp(), tab: 'Amis');
    await tester.scrollUntilVisible(
      find.byType(PrivacyCard),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final interrupteurs = [
      for (final noeud in noeuds(tester))
        if (noeud.getSemanticsData().flagsCollection.isToggled != Tristate.none)
          noeud,
    ];
    expect(interrupteurs, hasLength(1));
    final libelle = interrupteurs.single.label;
    expect(libelle, startsWith('Partager ma progression'));
    // Une ou deux lignes : le titre et sa précision, rien des voisins.
    expect('\n'.allMatches(libelle).length, lessThanOrEqualTo(1));
    expect(libelle, isNot(contains('DEMANDES')));
    expect(libelle, isNot(contains('ENCOURAGEMENTS')));
    semantics.dispose();
  });

  testWidgets('activer une ligne de l’onglet ne touche pas au réglage', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openCommunity(tester, sampleWorldApp(), tab: 'Amis');
    bool partage() => tester.widget<Switch>(find.byType(Switch)).value;
    final avant = partage();

    // Le double-tap du lecteur d'écran là où l'on entend « Nina » : c'est
    // le nom d'une amie, pas le réglage de confidentialité.
    final owner = tester.getSemantics(find.byType(Scaffold).first).owner!;
    final nina = [
      for (final noeud in noeuds(tester))
        if (noeud.label.contains('Nina')) noeud,
    ];
    expect(nina, isNotEmpty);
    for (final noeud in nina) {
      if (!noeud.getSemanticsData().hasAction(SemanticsAction.tap)) continue;
      owner.performAction(noeud.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(partage(), avant, reason: 'nœud « ${noeud.label} »');
    }
    // Sans laisser d'éventuelle feuille ouverte derrière soi.
    await tester.pumpAndSettle();
    semantics.dispose();
  });
}
