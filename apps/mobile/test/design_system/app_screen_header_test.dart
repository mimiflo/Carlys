import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// L'EN-TÊTE D'ÉCRAN ALIGNÉ À GAUCHE, en texte agrandi.
///
/// Ses boutons ronds prennent leur largeur au titre : « Communauté » se
/// coupait au milieu du mot dès ×1,3 sur 360 points (« Communa / uté »), et
/// en trois morceaux en ×2 sur 320. La variante centrée avait déjà sa
/// parade — le titre passe sous les boutons —, l'alignée ne l'avait pas.
void main() {
  setUpAll(loadAppFonts);

  Widget entete() => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          AppScreenHeader(
            title: 'Communauté',
            tagline: 'Ensemble, plus loin',
            showBack: false,
            actions: [
              AppRoundIconButton(
                icon: AppIcons.search,
                tooltip: 'Rechercher',
                onPressed: () {},
              ),
              AppRoundIconButton(
                icon: AppIcons.add,
                tooltip: 'Ajouter un ami',
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    ),
  );

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (360.0, 1.3),
    (360.0, 1.5),
    (320.0, 2.0),
  ]) {
    testWidgets('à $largeur points, texte ×$texte : le titre ne se coupe pas '
        'dans un mot', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(entete());

      expect(midWordBreaks(find.byType(AppScreenHeader)), isEmpty);
    });
  }

  testWidgets('à la taille d’origine, les boutons restent à côté du titre', (
    tester,
  ) async {
    setPhone(tester, width: 390);
    await tester.pumpWidget(entete());

    final titre = tester.getRect(find.text('Communauté'));
    final bouton = tester.getRect(find.byType(AppRoundIconButton).first);
    expect(bouton.left, greaterThan(titre.right));
    expect(bouton.top, lessThan(titre.bottom));
  });

  testWidgets('trop à l’étroit, les boutons passent au-dessus du titre', (
    tester,
  ) async {
    setPhone(tester, width: 320, textScale: 2);
    await tester.pumpWidget(entete());

    final titre = tester.getRect(find.text('Communauté'));
    final bouton = tester.getRect(find.byType(AppRoundIconButton).first);
    expect(bouton.bottom, lessThanOrEqualTo(titre.top));
  });
}
