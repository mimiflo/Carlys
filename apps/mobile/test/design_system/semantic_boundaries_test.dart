import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// UN GESTE DU DESIGN SYSTEM EST UNE FRONTIÈRE SÉMANTIQUE.
///
/// Une annotation `Semantics` sans `container` se FOND dans le premier
/// ancêtre qui pose une frontière — souvent l'élément de liste, qui
/// absorbe alors tout le texte voisin. L'audit de septembre 2026 l'a relevé
/// quatre fois (l'onglet Amis lu comme un interrupteur, la section
/// Récompenses comme un bouton « Voir les 4 », l'en-tête de l'accueil comme
/// le bouton du profil) ; la porte d'explication avait le même défaut : un
/// titre posé au-dessus d'elle s'annonçait « Titre de section, IMC : 24,7.
/// Explication », et l'activer ouvrait l'explication.
void main() {
  testWidgets('la porte d’explication n’absorbe pas le texte voisin', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var ouvertures = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: AppDarkScaffold(
          body: ListView(
            children: [
              Column(
                children: [
                  const Text('Titre de section'),
                  AppExplainable(
                    enonce: 'IMC : 24,7',
                    onExplain: () => ouvertures++,
                    child: const Text('24,7'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final porte = tester.getSemantics(find.byType(AppExplainable));
    expect(porte.label, 'IMC : 24,7. Explication');
    final titre = tester.getSemantics(find.text('Titre de section'));
    expect(titre.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

    porte.owner!.performAction(porte.id, SemanticsAction.tap);
    expect(ouvertures, 1);
    semantics.dispose();
  });
}
