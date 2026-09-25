import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Le bouton POINTILLÉ d'une liste qu'on remplit : « (+) Ajouter un
/// aliment », sous les lignes déjà posées.
///
/// Le pointillé dit « une place à prendre » là où un contour plein dirait
/// « un bouton parmi d'autres » : il se lit comme la ligne suivante de la
/// liste, encore vide. Toute la largeur, au moins la cible tactile ; le
/// violet clair du texte et du trait tient AA sur les surfaces sombres.
class AppDashedButton extends StatelessWidget {
  const AppDashedButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;

  /// `null` éteint le bouton (texte et trait tamisés).
  final VoidCallback? onPressed;

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final ink = enabled ? AppColors.primaryLight : AppColors.darkIconInactive;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.lgAll,
          overlayColor: const WidgetStatePropertyAll(AppColors.primaryBadgeBg),
          child: CustomPaint(
            painter: _DashedBorderPainter(color: ink),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.touchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: _iconSize, color: ink),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTypography.subheading.copyWith(color: ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le trait pointillé qui suit l'arrondi de la carte.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const double _dash = 6;
  static const double _gap = 4;
  static const double _stroke = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    final inset = _stroke / 2;
    final outline = Path()
      ..addRRect(
        AppRadius.lgAll.toRRect(
          Rect.fromLTWH(
            inset,
            inset,
            size.width - _stroke,
            size.height - _stroke,
          ),
        ),
      );
    for (final PathMetric metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
