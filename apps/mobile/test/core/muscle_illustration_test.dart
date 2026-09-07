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

  Future<ui.Image> render(ui.Image source, Color sourceRed) async {
    final shader = program.fragmentShader();
    final recorder = ui.PictureRecorder();
    MuscleIllustrationPainter(source, shader, sourceRed: sourceRed).paint(
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

  test('rouge des fessiers, relief et alpha préservés', () async {
    const colors = [
      Color(0xFFD36458), // Couleur médiane du dos.
      Color(0xFF69322C), // Ombre : environ la moitié de la médiane.
      Color(0xFFFD786A), // Zone éclairée : environ 120 %.
      Color(0xFF351916), // Ombre profonde : environ 25 %.
      Color(0xFF808080), // Corps gris : inchangé.
      Color(0xFF654588), // Liseré violet : inchangé.
      Color(0x80D36458), // Bord rouge semi-transparent.
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
    final output = await render(source, MuscleIllustration.sourceReds['dos']!);
    final bytes = (await output.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    const expected = [
      [234, 78, 69, 255],
      [116, 39, 35, 255],
      [255, 94, 83, 255],
      [59, 20, 17, 255],
      [128, 128, 128, 255],
      [101, 69, 136, 255],
      [234, 78, 69, 128],
      [0, 0, 0, 0],
    ];
    for (var i = 0; i < expected.length; i++) {
      final offset = (8 * output.width + i * 16 + 8) * 4;
      for (var channel = 0; channel < 4; channel++) {
        expect(
          bytes.getUint8(offset + channel),
          closeTo(expected[i][channel], 2),
          reason: 'Échantillon $i, canal $channel',
        );
      }
    }
    output.dispose();
    source.dispose();
  });

  test('les médianes des 13 images rejoignent le rouge des fessiers', () async {
    for (final entry in MuscleIllustration.sourceReds.entries) {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 16, 16),
        Paint()..color = entry.value,
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(16, 16);
      picture.dispose();
      final output = await render(source, entry.value);
      final bytes = (await output.toByteData())!;
      const expected = [234, 78, 69, 255];
      for (var channel = 0; channel < 4; channel++) {
        expect(
          bytes.getUint8((8 * 16 + 8) * 4 + channel),
          closeTo(expected[channel], 1),
          reason: entry.key,
        );
      }
      output.dispose();
      source.dispose();
    }
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
      final output = await render(source, MuscleIllustration.sourceReds[slug]!);
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
      if (slug == 'fessiers') {
        for (var i = 0; i < before.lengthInBytes; i++) {
          expect(after.getUint8(i), closeTo(before.getUint8(i), 1));
        }
      }
      output.dispose();
      source.dispose();
    }
  });
}
