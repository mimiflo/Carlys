import 'dart:ui' as ui;

import 'package:carlys_mobile/core/media/muscle_illustration.dart';
import 'package:carlys_mobile/features/exercises/presentation/widgets/muscle_group_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.FragmentProgram program;
  setUpAll(() async {
    program = await ui.FragmentProgram.fromAsset(
      MuscleIllustration.shaderAsset,
    );
  });

  Future<ui.Image> render(ui.Image source) async {
    final shader = program.fragmentShader();
    final recorder = ui.PictureRecorder();
    MuscleIllustrationPainter(source, shader).paint(
      Canvas(recorder),
      Size(source.width.toDouble(), source.height.toDouble()),
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(source.width, source.height);
    } finally {
      picture.dispose();
      shader.dispose();
    }
  }

  test('rouges différents, même cible et même alpha', () async {
    const colors = [
      Color(0xFFEB5342), // Abdominaux.
      Color(0xFFD36458), // Dos plus sombre.
      Color(0xFFF26D5B), // Avant-bras plus clair.
      Color(0xFF713124), // Ombre rouge.
      Color(0xFF808080), // Corps gris : inchangé.
      Color(0xFF654588), // Liseré violet : inchangé.
      Color(0x80E06050), // Bord rouge semi-transparent.
      Color(0x00000000), // Fond : toujours invisible.
    ];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < colors.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * 16.0, 0, 16, 16),
        Paint()..color = colors[i],
      );
    }
    final picture = recorder.endRecording();
    final source = await picture.toImage(colors.length * 16, 16);
    picture.dispose();
    final output = await render(source);
    final bytes = (await output.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    const expected = [
      [255, 77, 77, 255],
      [255, 77, 77, 255],
      [255, 77, 77, 255],
      [255, 77, 77, 255],
      [128, 128, 128, 255],
      [101, 69, 136, 255],
      [255, 77, 77, 128],
      [0, 0, 0, 0],
    ];
    for (var i = 0; i < expected.length; i++) {
      final offset = (8 * output.width + i * 16 + 8) * 4;
      for (var channel = 0; channel < 4; channel++) {
        expect(
          bytes.getUint8(offset + channel),
          closeTo(expected[i][channel], 1),
          reason: 'Échantillon $i, canal $channel',
        );
      }
    }
    output.dispose();
    source.dispose();
  });

  test('les 13 détourages gardent leur transparence après rendu', () async {
    final slugs = [MuscleGroupCard.allSlug, ...MuscleGroupCard.illustrated];
    expect(slugs, hasLength(13));
    for (final slug in slugs) {
      final asset = await rootBundle.load('assets/muscles/$slug.webp');
      final codec = await ui.instantiateImageCodec(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
      );
      final source = (await codec.getNextFrame()).image;
      codec.dispose();
      final output = await render(source);
      final before = (await source.toByteData())!;
      final after = (await output.toByteData())!;
      var transparentPixels = 0;
      var opaquePixels = 0;
      var maxAlphaDifference = 0;
      for (var i = 3; i < before.lengthInBytes; i += 4) {
        final alpha = before.getUint8(i);
        if (alpha == 0) transparentPixels++;
        if (alpha == 255) opaquePixels++;
        final difference = (alpha - after.getUint8(i)).abs();
        if (difference > maxAlphaDifference) maxAlphaDifference = difference;
      }
      expect(transparentPixels, greaterThan(1000), reason: slug);
      expect(opaquePixels, greaterThan(1000), reason: slug);
      expect(maxAlphaDifference, lessThanOrEqualTo(1), reason: slug);
      output.dispose();
      source.dispose();
    }
  });
}
