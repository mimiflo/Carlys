import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

/// Un anneau de progression : une piste discrète et un arc au dégradé
/// violet, qui part du haut et tourne dans le sens des aiguilles.
///
/// Né pour les calories du jour (Nutrition) : [child] se pose au centre.
/// Au-delà de 1, l'anneau reste plein — le dépassement se dit en texte.
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    required this.progress,
    required this.diameter,
    required this.child,
    this.stroke = 10,
    super.key,
  });

  final double progress;
  final double diameter;
  final double stroke;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: diameter,
      child: CustomPaint(
        painter: _RingPainter(progress: progress.clamp(0, 1), stroke: stroke),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.stroke});

  final double progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.gaugeTrack;
    canvas.drawArc(arc, 0, 2 * math.pi, false, track);
    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        endAngle: sweep,
        colors: const [AppColors.ctaStart, AppColors.ctaEnd],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arc, -math.pi / 2, sweep, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.stroke != stroke;
}
