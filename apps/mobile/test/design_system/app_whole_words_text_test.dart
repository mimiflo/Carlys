import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enlarged_text.dart';

/// Un texte dont aucun mot ne se coupe : il passe à la ligne entre deux
/// mots, et ne réduit son corps que si un mot SEUL déborde sa boîte.
void main() {
  setUpAll(loadAppFonts);

  const style = TextStyle(fontFamily: 'Inter', fontSize: 20);

  Future<void> poser(
    WidgetTester tester,
    String texte, {
    required double largeur,
    double echelle = 1,
    bool gras = false,
  }) async {
    setPhone(tester, width: 390, textScale: echelle);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(boldText: gras),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: largeur,
                  child: AppWholeWordsText(texte, style: style),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double corps(WidgetTester tester, String texte) =>
      tester.widget<Text>(find.text(texte)).style!.fontSize!;

  testWidgets('à l’aise, il ne touche à rien', (tester) async {
    await poser(tester, 'Communauté', largeur: 300);
    expect(corps(tester, 'Communauté'), 20);
  });

  testWidgets('plusieurs mots passent à la ligne sans changer de corps', (
    tester,
  ) async {
    await poser(tester, 'Amis uniquement', largeur: 120);
    expect(corps(tester, 'Amis uniquement'), 20);
    expect(midWordBreaks(find.byType(AppWholeWordsText)), isEmpty);
  });

  for (final echelle in const [1.0, 1.3, 2.0]) {
    testWidgets('un mot trop large se resserre au lieu de se couper '
        '(texte ×$echelle)', (tester) async {
      await poser(tester, 'Communauté', largeur: 60, echelle: echelle);
      expect(midWordBreaks(find.byType(AppWholeWordsText)), isEmpty);
      expect(corps(tester, 'Communauté'), lessThan(20));
      expect(
        tester.getSize(find.text('Communauté')).width,
        lessThanOrEqualTo(60),
      );
    });
  }

  testWidgets('réglage système « texte en gras » : mesuré comme dessiné', (
    tester,
  ) async {
    // `Text` passe tout en bold sous ce réglage : mesuré en graisse normale,
    // le mot se resserrait trop peu et se coupait quand même.
    await poser(tester, 'Communauté', largeur: 60, gras: true);
    expect(midWordBreaks(find.byType(AppWholeWordsText)), isEmpty);
  });

  testWidgets('l’espace insécable lie ses deux moitiés', (tester) async {
    // « 1 234 » avec un espace fine insécable est UN mot pour le moteur :
    // le mesurer en deux moitiés laisserait la coupure au milieu.
    await poser(tester, '12 345 678', largeur: 60);
    expect(
      tester.getSize(find.text('12 345 678')).height,
      lessThan(2 * 20 * 1.5),
      reason: 'une seule ligne',
    );
  });
}
