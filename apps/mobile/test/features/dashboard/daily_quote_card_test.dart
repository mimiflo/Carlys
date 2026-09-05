import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/dashboard/data/daily_quotes.dart';
import 'package:carlys_mobile/features/dashboard/domain/entities/daily_quote.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/daily_quote_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La carte reçoit une hauteur IMPOSÉE par la zone haute, et une largeur d'un
/// peu plus d'une demi-colonne. C'est la maxime qui s'y adapte — sinon le
/// cadre paraîtrait creux un jour et déborderait le lendemain.
void main() {
  /// Cadre du plus petit téléphone visé : colonne de gauche d'un écran de
  /// 320, hauteur telle que la calcule la zone haute.
  const cardSize = Size(152, 150);

  Future<void> pumpCard(WidgetTester tester, DailyQuote quote) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: Center(
            child: SizedBox(
              width: cardSize.width,
              height: cardSize.height,
              child: DailyQuoteCard(quote: quote),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('aucune maxime du recueil ne déborde de son cadre', (
    tester,
  ) async {
    for (final quote in carlysQuotes) {
      await pumpCard(tester, quote);

      expect(tester.takeException(), isNull, reason: quote.text);
      final rendered = tester.getSize(find.text(quote.text));
      expect(rendered.height, lessThanOrEqualTo(cardSize.height));
      expect(rendered.width, lessThanOrEqualTo(cardSize.width));
    }
  });

  testWidgets('la plus longue prend un corps plus petit que la plus courte', (
    tester,
  ) async {
    final byLength = [...carlysQuotes]
      ..sort((a, b) => a.text.length.compareTo(b.text.length));

    await pumpCard(tester, byLength.first);
    final shortest = tester
        .widget<Text>(find.text(byLength.first.text))
        .style!
        .fontSize!;

    await pumpCard(tester, byLength.last);
    final longest = tester
        .widget<Text>(find.text(byLength.last.text))
        .style!
        .fontSize!;

    expect(shortest, greaterThan(longest));
  });
}
