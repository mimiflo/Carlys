import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';
import 'league_metal.dart';

/// LE BLASON d'une division : un écu de métal, un creux sombre, un cristal.
///
/// Peint plutôt qu'importé : cinq images de blason pèseraient cinq fois plus
/// qu'un chemin, et leurs couleurs vivraient hors du design system. Ici,
/// seul le métal change d'une division à l'autre ([LeagueMetal]) : la forme
/// est la même, et c'est ce qui fait une famille.
class LeagueShield extends StatelessWidget {
  const LeagueShield({required this.division, this.size = 88, super.key});

  final LeagueDivision division;

  /// Hauteur du blason ; la largeur en vaut les 86 %.
  final double size;

  static const double aspect = 0.86;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Son propre nœud : fusionné dans la carte, le drapeau « image »
      // s'étendrait à tout son texte.
      container: true,
      image: true,
      label: 'Blason de la ligue ${division.label}',
      child: SizedBox(
        width: size * aspect,
        height: size,
        child: CustomPaint(painter: _ShieldPainter(LeagueMetal.of(division))),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter(this.metal);

  final LeagueMetal metal;

  /// L'écu, en fractions de la boîte : une pointe en haut, deux épaules, une
  /// pointe en bas. Le creux et le cristal reprennent la même géométrie.
  static const List<Offset> _outline = [
    Offset(0.5, 0),
    Offset(0.96, 0.17),
    Offset(0.86, 0.68),
    Offset(0.5, 1),
    Offset(0.14, 0.68),
    Offset(0.04, 0.17),
  ];

  static const List<Offset> _crystal = [
    Offset(0.5, 0.26),
    Offset(0.59, 0.37),
    Offset(0.59, 0.6),
    Offset(0.5, 0.73),
    Offset(0.41, 0.6),
    Offset(0.41, 0.37),
  ];

  Path _polygon(List<Offset> points, Size size, {double scale = 1}) {
    const centre = Offset(0.5, 0.48);
    Offset at(Offset p) {
      final scaled = centre + (p - centre) * scale;
      return Offset(scaled.dx * size.width, scaled.dy * size.height);
    }

    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final point in points.skip(1)) {
      path.lineTo(at(point).dx, at(point).dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // Un halo du métal, derrière : l'écu se détache du fond sombre de la
    // carte comme un objet, pas comme un aplat.
    canvas.drawPath(
      _polygon(_outline, size),
      Paint()
        ..color = metal.base.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.08),
    );

    // L'écu de métal, éclairé par le haut à gauche.
    canvas.drawPath(
      _polygon(_outline, size),
      Paint()..shader = metal.face.createShader(bounds),
    );

    // Le creux : un second écu, plus petit, dans l'ombre du métal.
    canvas.drawPath(
      _polygon(_outline, size, scale: 0.74),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [metal.dark, AppColors.darkBackground],
        ).createShader(bounds),
    );

    // Le filet du creux : la lumière accroche le biseau.
    canvas.drawPath(
      _polygon(_outline, size, scale: 0.74),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.025
        ..color = metal.light.withValues(alpha: 0.55),
    );

    // Le cristal, et son arête centrale.
    canvas.drawPath(
      _polygon(_crystal, size),
      Paint()..shader = metal.face.createShader(bounds),
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.26),
      Offset(size.width * 0.5, size.height * 0.73),
      Paint()
        ..color = metal.dark.withValues(alpha: 0.6)
        ..strokeWidth = size.width * 0.02,
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) =>
      oldDelegate.metal != metal;
}
