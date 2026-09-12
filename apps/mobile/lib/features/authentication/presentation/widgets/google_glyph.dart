import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Le « G » de Google, dessiné aux couleurs officielles.
///
/// Les quatre couleurs viennent de la filière des jetons (`tokens.json`,
/// groupe `color.vendor`, projeté dans [AppColors]) : ce sont des constantes
/// de la marque GOOGLE, pas des couleurs Carlys, et le groupe le dit — un
/// logo tiers ne se recolore pas plus que notre sceau ne se redessine.
///
/// Tracé : l'anneau en quatre arcs (rouge en haut, jaune à gauche, vert en
/// bas, bleu à droite), puis la barre horizontale bleue qui entre vers le
/// centre — la construction géométrique du logotype.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _GoogleGPainter(),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final radius = (size.width - stroke) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    const d = math.pi / 180;
    // Les quadrants du logotype, en angles Flutter (0° à 3 h, sens horaire) :
    // bleu de la barre au bas-droit, vert le bas, jaune la gauche, rouge le
    // haut. L'ouverture du G reste entre 315° et la barre — c'est elle qui
    // fait le G. Le bleu part exactement de 0° pour se souder à la barre.
    canvas
      ..drawArc(rect, 0 * d, 45 * d, false, paint..color = AppColors.googleBlue)
      ..drawArc(
        rect,
        45 * d,
        90 * d,
        false,
        paint..color = AppColors.googleGreen,
      )
      ..drawArc(
        rect,
        135 * d,
        90 * d,
        false,
        paint..color = AppColors.googleYellow,
      )
      ..drawArc(
        rect,
        225 * d,
        90 * d,
        false,
        paint..color = AppColors.googleRed,
      );

    // La barre du G : de l'ouverture vers le centre, à la même épaisseur.
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - stroke / 2,
        center.dx + radius + stroke / 2,
        center.dy + stroke / 2,
      ),
      Paint()..color = AppColors.googleBlue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
