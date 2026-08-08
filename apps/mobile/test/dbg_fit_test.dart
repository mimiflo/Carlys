import 'dart:convert';

import 'package:carlys_mobile/features/dashboard/domain/entities/daily_quote.dart';
import 'package:carlys_mobile/features/dashboard/presentation/widgets/home_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadRealFonts() async {
  final manifest = await rootBundle.loadStructuredData<List<dynamic>>(
    'FontManifest.json',
    (data) async => json.decode(data) as List<dynamic>,
  );
  for (final entry in manifest.whereType<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('hero réel', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeHero(
              displayName: 'Camille',
              subtitle: 'Récupération faite : le créneau est bon.',
              quote: DailyQuote(
                text: 'Ce que tu répètes devient ce que tu es.',
                value: CarlysValue.constance,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const quote = 'Ce que tu répètes devient ce que tu es.';
    final widget = tester.widget<Text>(find.text(quote));
    debugPrint('STYLE size=${widget.style?.fontSize} '
        'height=${widget.style?.height} maxLines=${widget.maxLines} '
        'overflow=${widget.overflow} family=${widget.style?.fontFamily}');
    debugPrint('TAILLE RENDUE=${tester.getSize(find.text(quote))}');
  });
}
