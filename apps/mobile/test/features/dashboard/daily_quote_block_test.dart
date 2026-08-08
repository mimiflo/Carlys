import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/dashboard/data/daily_quotes.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/daily_quote_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La maxime la plus longue du recueil doit tenir sur le plus petit téléphone
/// visé, sans débordement : la longueur du texte varie chaque jour, donc le
/// bloc ne peut pas être calibré sur un cas moyen.
void main() {
  testWidgets('aucune maxime ne déborde sur un petit écran', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final longest = carlysQuotes.reduce(
      (a, b) => a.text.length >= b.text.length ? a : b,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.darkBackground,
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: DailyQuoteBlock(quote: longest),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(longest.text), findsOneWidget);
  });
}
