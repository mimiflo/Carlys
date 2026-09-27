import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// LE LIBELLÉ D'UNE ACTION SE LIT EN ENTIER.
///
/// En texte ×2 sur 320 points, les boutons tenaient leur libellé sur UNE
/// ligne : « Supprimer ce repas » devenait « Supprimer ce » — coupé net,
/// sans ellipse, donc sans le moindre indice qu'il manquait un mot —,
/// « Accepter le défi » perdait « défi », « Enregistrer la modification »
/// finissait en ellipse dès ×1,5 sur 360. Texte agrandi, le libellé passe
/// désormais sur deux lignes et le bouton grandit ; à la taille d'origine,
/// rien ne change.
void main() {
  setUpAll(loadAppFonts);

  Widget colonne(List<Widget> boutons) => MaterialApp(
    theme: AppTheme.dark(),
    home: AppDarkScaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          for (final bouton in boutons) ...[
            bouton,
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    ),
  );

  List<Widget> boutons() => [
    AppButton(
      label: 'Supprimer ce repas',
      icon: AppIcons.delete,
      variant: AppButtonVariant.destructiveOutline,
      isExpanded: true,
      onPressed: () {},
    ),
    AppButton(
      label: 'Accepter le défi',
      icon: AppIcons.check,
      isExpanded: true,
      onPressed: () {},
    ),
    AppCtaButton(
      label: 'Enregistrer la modification',
      icon: AppIcons.check,
      onPressed: () {},
    ),
    AppCtaButton(
      label: 'Ajouter au journal',
      icon: AppIcons.add,
      onPressed: () {},
    ),
    AppBrandButton(
      label: 'Créer mon compte',
      uppercase: false,
      gradient: AppColors.cta,
      trailingIcon: AppIcons.arrowForward,
      onPressed: () {},
    ),
  ];

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (360.0, 1.5),
    (320.0, 2.0),
  ]) {
    testWidgets('à $largeur points, texte ×$texte : aucun libellé d’action '
        'n’est tronqué ni coupé dans un mot', (tester) async {
      setPhone(tester, width: largeur, textScale: texte);
      await tester.pumpWidget(colonne(boutons()));

      final page = find.byType(ListView);
      expect(truncatedTexts(page), isEmpty);
      expect(midWordBreaks(page), isEmpty);
    });
  }

  testWidgets('à la taille d’origine, chaque libellé tient sur une ligne', (
    tester,
  ) async {
    setPhone(tester, width: 390);
    await tester.pumpWidget(colonne(boutons()));

    for (final libelle in [
      'Supprimer ce repas',
      'Accepter le défi',
      'Enregistrer la modification',
      'Créer mon compte',
    ]) {
      final texte = tester.widget<Text>(find.text(libelle));
      expect(texte.maxLines, 1, reason: libelle);
    }
    // Et le bouton de marque garde sa hauteur de maquette.
    expect(
      tester.getSize(find.byType(AppBrandButton)).height,
      closeTo(58, 0.01),
    );
  });

  testWidgets('aucun libellé d’action n’est coupé net, sans ellipse', (
    tester,
  ) async {
    setPhone(tester, width: 320, textScale: 2);
    await tester.pumpWidget(colonne(boutons()));
    for (final texte in tester.widgetList<Text>(find.byType(Text))) {
      expect(texte.overflow, isNot(TextOverflow.clip), reason: texte.data);
    }
  });
}
