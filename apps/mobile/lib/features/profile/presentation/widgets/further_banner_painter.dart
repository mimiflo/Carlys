import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Le paysage de « Toujours plus loin » : une lune, trois crêtes, un
/// fanion au sommet.
///
/// Peint plutôt qu'importé : une image aurait figé ses couleurs hors du
/// design system, et le thème violet ne se répercuterait pas sur elle. Tout
/// ici vient d'`AppColors` ; les nombres ne sont que de la géométrie,
/// exprimée en fractions de la surface pour tenir à toutes les largeurs.
///
/// Le dessin occupe la moitié droite : la gauche reste au texte, sur le
/// fond nu de la carte, pour que le contraste AA ne dépende pas du décor.
class FurtherBannerPainter extends CustomPainter {
  const FurtherBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Le halo : la lumière vient de la droite, comme la lune.
    final halo = Rect.fromLTWH(w * 0.35, 0, w * 0.65, h);
    canvas.drawRect(
      halo,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.primaryCardClear, AppColors.backdropGlowSoft],
        ).createShader(halo),
    );

    // La lune, derrière les crêtes.
    final moon = Offset(w * 0.73, h * 0.5);
    canvas.drawCircle(
      moon,
      h * 0.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primaryDeep,
            AppColors.primaryDeep.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: h * 0.3)),
    );

    // Trois crêtes, de la plus lointaine (claire) à la plus proche (sombre).
    _ridge(canvas, size, AppColors.surfaceIcon, [
      (0.52, 1.0),
      (0.66, 0.62),
      (0.74, 0.7),
      (0.84, 0.28),
      (0.93, 0.55),
      (1.0, 0.48),
    ]);
    _ridge(canvas, size, AppColors.surfaceEngraved, [
      (0.46, 1.0),
      (0.6, 0.74),
      (0.7, 0.82),
      (0.79, 0.6),
      (0.9, 0.86),
      (1.0, 0.72),
    ]);
    _ridge(canvas, size, AppColors.darkSurfaceAlt, [
      (0.5, 1.0),
      (0.64, 0.9),
      (0.8, 0.94),
      (0.92, 0.84),
      (1.0, 0.9),
    ]);

    // Le fanion, planté sur le plus haut sommet.
    final foot = Offset(w * 0.84, h * 0.28);
    final top = Offset(foot.dx, h * 0.06);
    canvas.drawLine(
      foot,
      top,
      Paint()
        ..color = AppColors.primaryLight
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    final flag = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + h * 0.2, top.dy + h * 0.05)
      ..lineTo(top.dx + h * 0.13, top.dy + h * 0.09)
      ..lineTo(top.dx + h * 0.2, top.dy + h * 0.14)
      ..lineTo(top.dx, top.dy + h * 0.14)
      ..close();
    canvas.drawPath(flag, Paint()..color = AppColors.primary);
  }

  /// Une crête : des sommets donnés en fractions (x, y), fermée par le bas.
  void _ridge(
    Canvas canvas,
    Size size,
    Color color,
    List<(double, double)> peaks,
  ) {
    final path = Path()..moveTo(size.width * peaks.first.$1, size.height);
    for (final (x, y) in peaks) {
      path.lineTo(size.width * x, size.height * y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant FurtherBannerPainter oldDelegate) => false;
}
