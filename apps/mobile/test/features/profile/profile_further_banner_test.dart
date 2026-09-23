import 'dart:ui' as ui;

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/further_banner_illustration.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_further_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// « TOUJOURS PLUS LOIN » : une porte, et son illustration.
///
/// L'image est un DÉCOR : elle ne doit ni manquer au bundle, ni peser ce
/// que pesait le PNG fourni, ni parler au lecteur d'écran à la place du
/// texte de la porte.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('l’illustration est déclarée, se décode, et reste légère', () async {
    final data = await rootBundle.load(FurtherBannerIllustration.asset);

    // Le PNG fourni pesait 1,7 Mo ; le WebP 19 Ko. Le plafond laisse de la
    // marge à une retouche, pas à un retour du PNG.
    expect(data.lengthInBytes, lessThan(64 * 1024));

    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1280);
    expect(frame.image.height, 720);
    frame.image.dispose();
    codec.dispose();
  });

  Future<void> pumpBanner(WidgetTester tester, VoidCallback onTap) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: ProfileFurtherBanner(onTap: onTap)),
      ),
    );
  }

  testWidgets('l’illustration est posée, fondue, et muette', (tester) async {
    await pumpBanner(tester, () {});

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(FurtherBannerIllustration),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as AssetImage).assetName,
      FurtherBannerIllustration.asset,
    );
    expect(image.excludeFromSemantics, isTrue);
    // Le fondu par la gauche : sans lui, le bord de l'image se lirait comme
    // un trait vertical au milieu de la carte.
    expect(
      find.descendant(
        of: find.byType(FurtherBannerIllustration),
        matching: find.byType(ShaderMask),
      ),
      findsOneWidget,
    );
  });

  testWidgets('texte système doublé : la bannière grandit, rien ne déborde', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProfileFurtherBanner(onTap: () {}),
            ),
          ),
        ),
      ),
    );

    // Un débordement se signale par une exception de rendu : aucune.
    expect(tester.takeException(), isNull);
    final banner = tester.getSize(find.byType(ProfileFurtherBanner));
    expect(banner.height, greaterThan(96));
    // Et l'illustration couvre toujours toute la hauteur de la carte.
    expect(
      tester.getSize(find.byType(FurtherBannerIllustration)).height,
      closeTo(banner.height, 2),
    );
  });

  testWidgets('la porte s’annonce par son texte, et s’ouvre', (tester) async {
    final semantics = tester.ensureSemantics();
    var ouverte = false;
    await pumpBanner(tester, () => ouverte = true);

    expect(find.bySemanticsLabel(RegExp('Toujours plus loin')), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Toujours plus loin'))),
      matchesSemantics(
        label:
            'Toujours plus loin\nGarde l’élan et atteins\nde nouveaux objectifs.',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    await tester.tap(find.text('Toujours plus loin'));
    expect(ouverte, isTrue);
    semantics.dispose();
  });
}
