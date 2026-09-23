import 'dart:io';
import 'dart:math' as math;
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
/// texte de la porte — ni, surtout, passer sous le texte. La lune est le
/// point le plus clair de l'image : un sous-titre gris posé dessus tombait
/// à 2:1 de contraste dès qu'on agrandissait le texte système.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // La VRAIE police : la police carrée du moteur de test mesure chaque
  // glyphe à un cadratin, et ferait passer le titre à la ligne là où Inter
  // le tient sur une. `FontLoader` n'expose pas la graisse : le GRAS est
  // chargé seul, pour tous les textes — la mesure surestime les largeurs,
  // ce qui ne peut que durcir l'exigence (même choix que
  // `welcome_text_clearance_test.dart`).
  setUpAll(() async {
    final loader = FontLoader(AppTypography.textFamily)
      ..addFont(
        File(
          'assets/fonts/Inter-Bold.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
  });

  /// Bord gauche de la lune, en fraction de la largeur de l'image — mesuré
  /// sur le fichier (colonne 377 sur 1280), pas déduit du code.
  const moonLeftFraction = 0.2945;

  /// Rapport largeur / hauteur de l'image.
  const imageAspect = 1280 / 720;

  /// L'écart minimal exigé entre la fin du texte et le bord de la lune. Le
  /// widget borne son texte à 8 points avant l'endroit où l'image devient
  /// pleine ; la lune commence un point plus tôt que ce point-là.
  const minGapToMoon = 6.0;

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

  /// La bannière comme sur le profil : un écran de [width] points en
  /// densité 3, la gouttière de 16, le texte système à [scale].
  Future<void> pumpBanner(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
    VoidCallback? onTap,
  }) async {
    tester.view.physicalSize = Size(width * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [ProfileFurtherBanner(onTap: onTap ?? () {})],
          ),
        ),
      ),
    );
  }

  /// La boîte de l'illustration : le fondu horizontal, le plus extérieur.
  Rect boxOf(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byType(FurtherBannerIllustration),
          matching: find.byType(ShaderMask),
        )
        .first,
  );

  testWidgets('l’illustration est posée, fondue, et muette', (tester) async {
    await pumpBanner(tester);

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

    // Le fondu : transparent au bord gauche, plein à 30 % de la boîte.
    final mask = tester.widget<ShaderMask>(
      find
          .descendant(
            of: find.byType(FurtherBannerIllustration),
            matching: find.byType(ShaderMask),
          )
          .first,
    );
    expect(mask.blendMode, BlendMode.dstIn);
    expect(FurtherBannerIllustration.fadeStops, [0, 0.3]);

    // La boîte est à DROITE de la carte, sur 62 % de sa largeur.
    final card = tester.getRect(find.byType(ProfileFurtherBanner));
    final box = boxOf(tester);
    expect(box.right, closeTo(card.right, 1));
    expect(box.width, closeTo(card.width * 0.62, 1));
    expect(box.height, closeTo(card.height, 2));
  });

  // LE TEXTE NE PASSE JAMAIS SUR LA LUNE, quelle que soit la largeur de
  // l'écran et la taille du texte système. La position de la lune est
  // recalculée ici depuis le cadrage réel de l'image, indépendamment de la
  // géométrie que le widget publie.
  const cases = <(double, double)>[
    (393, 1), // la référence de la maquette
    (320, 1), // petit téléphone
    (360, 1.3), // Android « la plus grande »
    (393, 23 / 17), // iPhone en taille de texte XXXL
    (393, 2), // texte système doublé
    (430, 1.5),
    (800, 1), // tablette
  ];
  for (final (width, scale) in cases) {
    testWidgets('$width pt, texte ×${scale.toStringAsFixed(2)} : '
        'le texte reste à gauche de la lune, rien ne déborde', (tester) async {
      await pumpBanner(tester, width: width, scale: scale);
      expect(tester.takeException(), isNull);

      // Le cadrage, recalculé comme `BoxFit.cover` le fait, depuis le
      // rectangle RÉEL de l'image et l'alignement réellement posé : l'image
      // couvre son rectangle, et l'alignement décide de quel côté elle
      // déborde.
      final imageFinder = find.descendant(
        of: find.byType(FurtherBannerIllustration),
        matching: find.byType(Image),
      );
      final frame = tester.getRect(imageFinder);
      final painted = math.max(frame.width, frame.height * imageAspect);
      final alignment =
          (tester.widget<Image>(imageFinder).alignment as Alignment).x;
      final overflowLeft = (painted - frame.width) * (alignment + 1) / 2;
      final moonLeft = frame.left - overflowLeft + moonLeftFraction * painted;

      for (final label in ['Toujours plus loin', 'Garde']) {
        final text = tester.getRect(find.textContaining(label));
        expect(
          text.right,
          lessThanOrEqualTo(moonLeft - minGapToMoon),
          reason:
              '« $label » s’étend jusqu’à ${text.right} pt, la lune '
              'commence à $moonLeft pt',
        );
      }
      // La boîte de l'illustration suit la carte, même agrandie par le
      // texte ; l'image, elle, garde son cadrage de référence : jamais
      // agrandie au-delà de la largeur de sa boîte.
      final card = tester.getRect(find.byType(ProfileFurtherBanner));
      final box = boxOf(tester);
      expect(box.height, closeTo(card.height, 2));
      expect(painted, closeTo(box.width, 1));
    });
  }

  testWidgets('à la taille normale, rien ne change : titre sur une ligne', (
    tester,
  ) async {
    await pumpBanner(tester);
    final card = tester.getRect(find.byType(ProfileFurtherBanner));
    expect(card.height, FurtherBannerIllustration.referenceHeight);
    final title = tester.getSize(find.text('Toujours plus loin'));
    final oneLine = AppTypography.resized(AppTypography.title, 19);
    expect(title.height, lessThan(oneLine.fontSize! * 2));
  });

  testWidgets('texte doublé : la bannière grandit au lieu de déborder', (
    tester,
  ) async {
    await pumpBanner(tester, scale: 2);
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byType(ProfileFurtherBanner));
    expect(card.height, greaterThan(FurtherBannerIllustration.referenceHeight));
  });

  testWidgets('tablette : la boîte garde le cadrage du téléphone', (
    tester,
  ) async {
    // Élargie en proportion de la carte, la boîte faisait agrandir l'image
    // par `BoxFit.cover`, qui en rognait le haut — et le fanion avec.
    await pumpBanner(tester, width: 800);
    final box = boxOf(tester);
    expect(
      box.width,
      closeTo(
        FurtherBannerIllustration.referenceHeight *
            FurtherBannerIllustration.maxAspect,
        0.5,
      ),
    );
  });

  testWidgets('l’encre de l’appui passe AU-DESSUS de l’image', (tester) async {
    await pumpBanner(tester);

    // L'InkWell peint son encre sur le Material le plus proche. S'il
    // s'agit de celui de la carte, l'image la recouvre et la moitié droite
    // de la porte ne réagit plus au doigt.
    final host = tester.widget<Material>(
      find
          .ancestor(of: find.byType(InkWell), matching: find.byType(Material))
          .first,
    );
    expect(host.type, MaterialType.transparency);

    final stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byType(FurtherBannerIllustration),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(stack.children.first, isA<Positioned>());
    expect(stack.children.last, isA<Material>());
  });

  testWidgets('la porte s’annonce par son texte, et s’ouvre au chevron', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var ouverte = false;
    await pumpBanner(tester, onTap: () => ouverte = true);

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Toujours plus loin'))),
      matchesSemantics(
        label:
            'Toujours plus loin\nGarde l’élan et atteins de\u00A0nouveaux objectifs.',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    // Le chevron est posé sur l'image : c'est là qu'on touche le plus.
    await tester.tap(find.byIcon(AppIcons.chevronRight));
    expect(ouverte, isTrue);
    semantics.dispose();
  });
}
