import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// LA LIGNE DE LISTE ET SA VALEUR DE FIN, en texte agrandi.
///
/// Même motif que les lignes de réglage : un titre qui s'étire, puis une
/// valeur de fin qui ne plie pas. Sur la fiche d'un programme, « Premier
/// jour » se coupait en son milieu dès ×1,5 sur 360 points, face à sa date,
/// et la ligne débordait de 27 points en ×2 sur 320. Texte agrandi, la
/// valeur passe désormais SOUS le titre.
void main() {
  setUpAll(loadAppFonts);

  Widget ligne() => MaterialApp(
    theme: AppTheme.dark(),
    home: AppDarkScaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          AppCard(
            child: AppListRow(
              title: 'Premier jour',
              trailingText: '21/09/2026',
              leading: AppIcons.date,
              onTap: () {},
            ),
          ),
        ],
      ),
    ),
  );

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (360.0, 1.5),
    (320.0, 2.0),
  ]) {
    testWidgets('à $largeur points, texte ×$texte : titre et date entiers', (
      tester,
    ) async {
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(ligne());

      final rangee = find.byType(AppListRow);
      expect(midWordBreaks(rangee), isEmpty);
      expect(truncatedTexts(rangee), isEmpty);
      expect(find.text('21/09/2026'), findsOneWidget);
    });
  }

  testWidgets('à la taille d’origine, la date reste à droite du titre', (
    tester,
  ) async {
    setPhone(tester, width: 390);
    await tester.pumpWidget(ligne());
    expect(
      tester.getRect(find.text('21/09/2026')).left,
      greaterThan(tester.getRect(find.text('Premier jour')).right),
    );
  });
}
