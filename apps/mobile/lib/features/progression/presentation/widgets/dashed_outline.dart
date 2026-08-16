import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// LE CONTOUR EN TIRETS : « pas encore », jamais « désactivé ».
///
/// Un trait plein dirait que la carte existe déjà ; un gris dirait qu'elle
/// est hors service. Les tirets disent la seule chose vraie : elle attend.
/// C'est le même contour pour une invitation de la vitrine et pour la
/// première récompense d'un compte neuf — deux façons de dire « à venir »
/// mériteraient deux significations.
class DashedOutline extends CustomPainter {
  const DashedOutline({
    required this.radius,
    this.stroke = AppColors.darkBorderStrong,
  });

  final double radius;
  final Color stroke;

  /// Longueur d'un tiret, et de l'espace qui le suit.
  static const double dash = 6;

  /// La surface en retrait : présente, mais moins que celle d'une carte
  /// gagnée.
  static const double _fillOpacity = 0.6;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = AppColors.darkSurface.withValues(alpha: _fillOpacity),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = stroke;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash * 2;
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutline old) =>
      old.radius != radius || old.stroke != stroke;
}
