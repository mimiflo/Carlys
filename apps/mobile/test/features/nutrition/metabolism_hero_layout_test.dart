import 'dart:ui' as ui;

import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/domain/entities/nutrition.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/metabolism_hero.dart';
import 'package:carlys_mobile/features/nutrition/presentation/widgets/metabolism_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/enlarged_text.dart';

/// LE HERO « TON MOTEUR AUJOURD'HUI », en texte agrandi.
///
/// Le premier bloc de l'onglet Nutrition avait une hauteur FIXE (378) et
/// posait la décomposition MB / Activité À CÔTÉ de la dépense totale, sans
/// rien de flexible : dès 360 points en texte ×1,3, « KCAL / DÉPENSE
/// TOTALE » passait sous « ACTIVITÉ 979 » ; en ×2 sur 320 points, le chiffre
/// lui-même se coupait (« 2 75 / 9 ») et sortait du hero par le bas.
void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    // L'hélice ADN tourne en boucle : animations réduites.
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  const resultat = MetabolismResult(
    bmi: 24.7,
    bmiCategory: BmiCategory.normal,
    bmrKcal: 1780,
    tdeeKcal: 2759,
    targetKcal: 2345,
    proteinG: 128,
    fatG: 65,
    carbsG: 291,
    waterMl: 2800,
  );

  Widget onglet() => MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: ListView(
        children: [
          MetabolismHero(metabolism: resultat, onCompleteProfile: () {}),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: MetabolismView(metabolism: resultat),
          ),
        ],
      ),
    ),
  );

  bool chevauche(WidgetTester tester, Finder a, Finder b) {
    final ra = tester.getRect(a);
    final rb = tester.getRect(b);
    return ra.overlaps(rb) && !ra.intersect(rb).isEmpty;
  }

  for (final (largeur, texte) in const [
    (390.0, 1.0),
    (360.0, 1.3),
    (360.0, 1.5),
    (390.0, 1.5),
    (390.0, 2.0),
    (320.0, 2.0),
  ]) {
    testWidgets('à $largeur points, texte ×$texte : rien ne déborde, rien ne '
        'se chevauche, aucun chiffre ne se coupe', (tester) async {
      setPhone(tester, width: largeur, height: 1600, textScale: texte);
      await tester.pumpWidget(onglet());
      await tester.pump();

      final hero = find.byType(MetabolismHero);
      expect(midWordBreaks(hero), isEmpty);
      expect(
        chevauche(
          tester,
          find.text('KCAL / DÉPENSE TOTALE'),
          find.text('ACTIVITÉ 979'),
        ),
        isFalse,
      );
      expect(
        chevauche(
          tester,
          find.text('KCAL / DÉPENSE TOTALE'),
          find.text('MB ${formatThousands(1780)}'),
        ),
        isFalse,
      );
      // Le chiffre et la décomposition restent DANS le hero.
      final cadre = tester.getRect(hero);
      for (final texteVu in [formatThousands(2759), 'ACTIVITÉ 979']) {
        expect(
          cadre.contains(
            tester.getRect(find.text(texteVu)).bottomRight -
                const Offset(0.5, 0.5),
          ),
          isTrue,
          reason: '« $texteVu » sort du hero',
        );
      }
      expect(midWordBreaks(find.byType(MetabolismView)), isEmpty);
    });
  }

  testWidgets('la décomposition MB / Activité est une cible de 48 points', (
    tester,
  ) async {
    setPhone(tester, width: 390);
    await tester.pumpWidget(onglet());
    await tester.pump();

    final porte = find.ancestor(
      of: find.text('MB ${formatThousands(1780)}'),
      matching: find.byType(AppExplainable),
    );
    expect(
      tester.getSize(porte).height,
      greaterThanOrEqualTo(AppSpacing.touchTarget),
    );
  });

  testWidgets('à la taille d’origine, le hero garde sa hauteur de maquette', (
    tester,
  ) async {
    setPhone(tester, width: 390);
    await tester.pumpWidget(onglet());
    await tester.pump();

    expect(tester.getSize(find.byType(MetabolismHero)).height, 378);
  });

  testWidgets('sous « Sombre OLED », le bas du hero se fond dans la page '
      'noire, sans couture', (tester) async {
    // Les voiles du hero finissaient en `darkBackground` en dur : sous
    // l'OLED, une bande #08050E / #000000 barrait l'écran au pied du hero.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cadre = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.oledDark(),
        home: RepaintBoundary(
          key: cadre,
          child: Scaffold(
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                MetabolismHero(metabolism: resultat, onCompleteProfile: () {}),
                const SizedBox(height: 300),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary =
        cadre.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final octets = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    List<int> pixel(int x, int y) => [
      for (var canal = 0; canal < 3; canal++)
        octets.getUint8((y * image.width + x) * 4 + canal),
    ];

    final pied = tester.getRect(find.byType(MetabolismHero)).bottom.floor();
    for (final x in const [20, 300]) {
      final dessus = pixel(x, pied - 2);
      final dessous = pixel(x, pied + 10);
      expect(dessous, [0, 0, 0], reason: 'la page OLED est noire');
      for (var canal = 0; canal < 3; canal++) {
        expect(
          (dessus[canal] - dessous[canal]).abs(),
          lessThanOrEqualTo(2),
          reason: 'x = $x : $dessus au pied du hero, $dessous dessous',
        );
      }
    }
    image.dispose();
  });
}
