/// La PHOTO d'exemple du déjeuner de la maquette (poulet, riz, brocoli),
/// DESSINÉE plutôt qu'embarquée.
///
/// L'application n'a aucune photo de plat parmi ses images (et n'a pas à en
/// porter une pour ses captures) ; une image d'asset existante (l'athlète de
/// la page de bienvenue) aurait montré autre chose qu'une assiette. Le
/// dessin est vu de dessus, à plat, et DÉTERMINISTE : même graine, mêmes
/// octets, donc la même capture d'une exécution à l'autre.
///
/// Les couleurs sont celles d'une assiette, pas de l'interface : c'est une
/// donnée d'exemple, hors du design system.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List? _cached;

/// Un JPEG carré de 480 px : la table, l'assiette, et ses trois aliments.
Uint8List sampleMealPhotoJpeg() =>
    _cached ??= img.encodeJpg(_drawPlate(), quality: 85);

img.Image _drawPlate() {
  const size = 480;
  const center = size ~/ 2;
  final random = math.Random(7);
  final photo = img.Image(width: size, height: size)
    ..clear(img.ColorRgb8(58, 42, 34));

  // Le bois de la table : des veines horizontales, à peine plus claires.
  for (var y = 0; y < size; y += 9 + random.nextInt(9)) {
    img.drawLine(
      photo,
      x1: 0,
      y1: y,
      x2: size,
      y2: y + random.nextInt(7) - 3,
      color: img.ColorRgb8(70, 51, 41),
      thickness: 2,
    );
  }

  // L'assiette : un bord, puis le creux.
  img.fillCircle(
    photo,
    x: center,
    y: center,
    radius: 214,
    color: img.ColorRgb8(226, 224, 218),
    antialias: true,
  );
  img.fillCircle(
    photo,
    x: center,
    y: center,
    radius: 180,
    color: img.ColorRgb8(246, 245, 240),
    antialias: true,
  );

  _rice(photo, random, x: 292, y: 292);
  _chicken(photo, x: 170, y: 170);
  _broccoli(photo, random, x: 170, y: 320);
  return photo;
}

/// Le riz : un dôme blanc cassé, grains dessinés un à un.
void _rice(
  img.Image photo,
  math.Random random, {
  required int x,
  required int y,
}) {
  img.fillCircle(
    photo,
    x: x,
    y: y,
    radius: 78,
    color: img.ColorRgb8(238, 233, 214),
    antialias: true,
  );
  for (var grain = 0; grain < 260; grain++) {
    final angle = random.nextDouble() * math.pi * 2;
    final distance = math.sqrt(random.nextDouble()) * 72;
    final gx = x + (math.cos(angle) * distance).round();
    final gy = y + (math.sin(angle) * distance).round();
    img.drawLine(
      photo,
      x1: gx,
      y1: gy,
      x2: gx + random.nextInt(7) - 3,
      y2: gy + random.nextInt(5) - 2,
      color: random.nextBool()
          ? img.ColorRgb8(252, 250, 242)
          : img.ColorRgb8(214, 207, 186),
      thickness: 2,
    );
  }
}

/// Le poulet : quatre tranches dorées, marquées par le gril.
void _chicken(img.Image photo, {required int x, required int y}) {
  for (var slice = 0; slice < 4; slice++) {
    final dx = x - 60 + slice * 34;
    final dy = y - 40 + slice * 10;
    img.fillPolygon(
      photo,
      vertices: [
        img.Point(dx, dy),
        img.Point(dx + 30, dy - 12),
        img.Point(dx + 58, dy + 70),
        img.Point(dx + 26, dy + 84),
      ],
      color: img.ColorRgb8(214, 162, 98),
    );
    for (var mark = 0; mark < 3; mark++) {
      img.drawLine(
        photo,
        x1: dx + 8 + mark * 6,
        y1: dy + 12 + mark * 20,
        x2: dx + 34 + mark * 6,
        y2: dy + 2 + mark * 20,
        color: img.ColorRgb8(146, 94, 48),
        thickness: 3,
      );
    }
  }
}

/// Le brocoli : des bouquets de sommités autour de leurs tiges.
void _broccoli(
  img.Image photo,
  math.Random random, {
  required int x,
  required int y,
}) {
  const florets = [(0, 0), (-38, 24), (34, 30), (-6, 52), (40, -10)];
  for (final (fx, fy) in florets) {
    img.drawLine(
      photo,
      x1: x + fx,
      y1: y + fy,
      x2: x + fx + 10,
      y2: y + fy + 34,
      color: img.ColorRgb8(150, 190, 110),
      thickness: 9,
    );
  }
  for (final (fx, fy) in florets) {
    for (var bud = 0; bud < 14; bud++) {
      img.fillCircle(
        photo,
        x: x + fx + random.nextInt(30) - 15,
        y: y + fy + random.nextInt(24) - 14,
        radius: 7 + random.nextInt(6),
        color: random.nextBool()
            ? img.ColorRgb8(58, 128, 54)
            : img.ColorRgb8(84, 156, 66),
        antialias: true,
      );
    }
  }
}
