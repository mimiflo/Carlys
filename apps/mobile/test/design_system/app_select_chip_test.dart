import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// LA PASTILLE DE CHOIX (« Mois » des progrès, « Aujourd'hui » du journal) :
/// elle dit sa valeur ET son geste au lecteur d'écran, répond au doigt comme
/// à l'activation vocale, et coupe son libellé plutôt que de déborder.
void main() {
  setUpAll(loadAppFonts);

  Widget monte(String label, VoidCallback onTap) => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppSelectChip(
            label: label,
            semanticsLabel: 'Période analysée : $label. Changer',
            onTap: onTap,
          ),
        ],
      ),
    ),
  );

  testWidgets('le lecteur d’écran entend un bouton, sa valeur et son geste', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var appuis = 0;
    await tester.pumpWidget(monte('Mois', () => appuis++));

    final noeud = find.bySemanticsLabel('Période analysée : Mois. Changer');
    expect(
      tester.getSemantics(noeud),
      matchesSemantics(
        label: 'Période analysée : Mois. Changer',
        isButton: true,
        hasTapAction: true,
      ),
    );
    // Le libellé visible ne forme pas un second nœud qui doublerait
    // l'annonce.
    expect(find.bySemanticsLabel('Mois'), findsNothing);

    // L'activation vocale passe par le nœud, pas par l'InkWell exclu.
    tester.semantics.tap(
      find.semantics.byLabel('Période analysée : Mois. Changer'),
    );
    expect(appuis, 1);
    semantics.dispose();
  });

  testWidgets('un appui du doigt relaie le geste', (tester) async {
    var appuis = 0;
    await tester.pumpWidget(monte('Aujourd’hui', () => appuis++));

    await tester.tap(find.byType(AppSelectChip));
    expect(appuis, 1);
  });

  testWidgets('posée dans une rangée qui ne la borne pas, un long libellé '
      'se coupe sans déborder sur 320 points en texte ×2', (tester) async {
    setPhone(tester, width: 320, textScale: 2);
    await tester.pumpWidget(
      monte('Du lundi 28 septembre au dimanche 4 octobre 2026', () {}),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AppSelectChip)).width,
      lessThanOrEqualTo(320 - 2 * AppSpacing.md),
    );
  });
}
