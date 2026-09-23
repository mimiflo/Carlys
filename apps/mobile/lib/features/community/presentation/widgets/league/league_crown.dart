import 'package:flutter/material.dart';

import 'league_metal.dart';

/// LA COURONNE d'une place du podium : or, argent, bronze.
///
/// Peinte : la banque d'icônes Material n'a aucune couronne (celle qui en
/// porte le nom dans `AppIcons` dessine des étincelles), et le dépôt ne
/// charge aucun paquet d'icônes pour une seule forme.
class LeagueCrown extends StatelessWidget {
  const LeagueCrown({required this.metal, this.size = 22, super.key});

  final LeagueMetal metal;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _CrownPainter(metal)),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter(this.metal);

  final LeagueMetal metal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..shader = metal.face.createShader(Offset.zero & size);

    // Trois pointes sur un bandeau, en fractions de la boîte.
    final crown = Path()
      ..moveTo(w * 0.08, h * 0.82)
      ..lineTo(w * 0.08, h * 0.36)
      ..lineTo(w * 0.31, h * 0.56)
      ..lineTo(w * 0.5, h * 0.22)
      ..lineTo(w * 0.69, h * 0.56)
      ..lineTo(w * 0.92, h * 0.36)
      ..lineTo(w * 0.92, h * 0.82)
      ..close();
    canvas.drawPath(crown, paint);

    // Une perle au bout de chaque pointe.
    for (final tip in [
      Offset(w * 0.08, h * 0.32),
      Offset(w * 0.5, h * 0.17),
      Offset(w * 0.92, h * 0.32),
    ]) {
      canvas.drawCircle(tip, w * 0.075, paint);
    }

    // Le bandeau, un ton plus sombre : il donne sa base à la couronne.
    canvas.drawRect(
      Rect.fromLTRB(w * 0.08, h * 0.72, w * 0.92, h * 0.82),
      Paint()..color = metal.dark,
    );
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) =>
      oldDelegate.metal != metal;
}
