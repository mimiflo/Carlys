import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../motion/app_motion.dart';
import '../typography/app_typography.dart';

/// Anneau de forme (score) : arc accent sur piste sombre, valeur mono au
/// centre. Anime 0 → valeur en [AppMotion.ring] `easeOutCubic` au premier
/// build (respect de la réduction d'animations système).
class AppFormRing extends StatefulWidget {
  const AppFormRing({
    required this.value,
    required this.label,
    this.diameter = 96,
    this.strokeWidth = 9,
    this.max = 100,
    super.key,
  });

  final int value;
  final String label;
  final double diameter;
  final double strokeWidth;
  final int max;

  @override
  State<AppFormRing> createState() => _AppFormRingState();
}

class _AppFormRingState extends State<AppFormRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.ring);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Résolue ici (MediaQuery indisponible en initState).
    if (_controller.status == AnimationStatus.dismissed) {
      if (AppMotion.resolve(context, AppMotion.ring) == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (widget.value / widget.max).clamp(0.0, 1.0);
    return Semantics(
      label: '${widget.label} : ${widget.value}',
      child: SizedBox(
        width: widget.diameter,
        height: widget.diameter,
        child: AnimatedBuilder(
          animation: _curve,
          builder: (context, _) {
            final shown = (fraction * _curve.value * widget.max).round();
            return CustomPaint(
              painter: _RingPainter(
                fraction: fraction * _curve.value,
                strokeWidth: widget.strokeWidth,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$shown',
                      style: AppTypography.metricL.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.label.toUpperCase(),
                      style: AppTypography.labelMono.copyWith(
                        fontSize: 8,
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.strokeWidth});

  final double fraction;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Trou central rempli — la carte reste lisible derrière la valeur.
    canvas.drawCircle(
      center,
      radius + strokeWidth / 2 - 1,
      Paint()..color = AppColors.ringHole,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.gaugeTrack;
    canvas.drawCircle(center, radius, track);

    if (fraction > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.strokeWidth != strokeWidth;
}
