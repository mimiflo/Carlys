import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texte qui se dimensionne pour remplir sa boîte.
///
/// Le besoin : la citation du jour reçoit toujours le même cadre alors que
/// les maximes vont du simple au double en longueur. Sans ajustement, le
/// cadre paraîtrait creux un jour et déborderait le lendemain.
void main() {
  const box = Size(200, 160);

  Future<double> sizeOf(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: AppFittedText(
                text,
                minFontSize: 12,
                maxFontSize: 40,
                style: const TextStyle(height: 1.3),
              ),
            ),
          ),
        ),
      ),
    );
    return tester.widget<Text>(find.text(text)).style!.fontSize!;
  }

  testWidgets('une phrase courte prend un plus grand corps qu’une longue',
      (tester) async {
    final short = await sizeOf(tester, 'Le tempo est une charge invisible.');
    final long = await sizeOf(
      tester,
      'Maîtriser, c’est pouvoir s’arrêter à n’importe quel moment du geste, '
      'et cette phrase est délibérément très longue pour le vérifier.',
    );

    expect(short, greaterThan(long));
  });

  testWidgets('le texte ne dépasse jamais la boîte reçue', (tester) async {
    for (final text in [
      'Court.',
      'Une maxime de longueur moyenne, comme la plupart du recueil.',
      'Une maxime démesurée, répétée encore et encore, bien au-delà de ce '
          'que le cadre peut contenir au corps maximum, pour forcer la '
          'réduction jusqu’à la borne basse et vérifier qu’il n’y a aucun '
          'débordement possible.',
    ]) {
      await sizeOf(tester, text);
      expect(tester.takeException(), isNull, reason: text);

      final rendered = tester.getSize(find.text(text));
      expect(rendered.height, lessThanOrEqualTo(box.height), reason: text);
      expect(rendered.width, lessThanOrEqualTo(box.width), reason: text);
    }
  });

  testWidgets('les bornes sont respectées', (tester) async {
    final size = await sizeOf(tester, 'x');

    // Une phrase minuscule ne dépasse pas le corps maximal demandé.
    expect(size, lessThanOrEqualTo(40));
    expect(size, greaterThanOrEqualTo(12));
  });

  testWidgets('sans hauteur bornée, le corps maximal est retenu',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 200,
              child: AppFittedText(
                'Rien à remplir ici.',
                minFontSize: 12,
                maxFontSize: 40,
                style: TextStyle(height: 1.3),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Rien à remplir ici.')).style!.fontSize,
      40,
    );
  });
}
