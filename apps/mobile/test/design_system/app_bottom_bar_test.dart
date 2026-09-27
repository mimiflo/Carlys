import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// LA BARRE D'ONGLETS, en texte agrandi et au lecteur d'écran.
///
/// Un onglet fait un sixième de l'écran : 65 points sur 390, 53 sur 320.
/// « Communauté » y passait à la ligne AU MILIEU du mot (« Communaut / é »)
/// dès le texte ×1,15, premier cran d'Android — sur chacun des écrans
/// principaux. Et chaque onglet s'annonçait deux fois (« Accueil Accueil »),
/// le libellé visible s'ajoutant à celui de la sémantique.
void main() {
  setUpAll(loadAppFonts);

  Widget barre() => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      bottomNavigationBar: AppBottomBar(currentIndex: 0, onTap: (_) {}),
    ),
  );

  for (final (largeur, texte) in const [
    (390.0, 1.15),
    (360.0, 1.3),
    (320.0, 1.0),
    (320.0, 2.0),
  ]) {
    testWidgets('à $largeur points, texte ×$texte, aucun libellé ne se coupe '
        'dans un mot ni ne sort de la barre', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(barre());

      final bar = find.byType(AppBottomBar);
      expect(midWordBreaks(bar), isEmpty);
      expect(truncatedTexts(bar), isEmpty);
      // Chaque libellé tient dans son onglet.
      final largeurOnglet = largeur / appBottomBarItems.length;
      for (final item in appBottomBarItems) {
        expect(
          tester.getRect(find.text(item.label)).width,
          lessThanOrEqualTo(largeurOnglet + 0.01),
          reason: item.label,
        );
      }
    });
  }

  testWidgets('chaque onglet s’annonce une fois, sélection comprise', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(barre());

    for (final (index, item) in appBottomBarItems.indexed) {
      final noeud = tester.getSemantics(
        find
            .ancestor(of: find.text(item.label), matching: find.byType(InkWell))
            .first,
      );
      expect(noeud.label, item.label);
      expect(
        noeud,
        isSemantics(
          label: item.label,
          isButton: true,
          isSelected: index == 0,
          hasSelectedState: true,
        ),
      );
    }
    semantics.dispose();
  });
}
