import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/scene_math.dart';

/// Double hélice d'ADN (handoff/animations-3d.md + dna-helix.js).
///
/// Deux brins déphasés de π (primary / primaryLight), barreaux en DEUX
/// demi-bâtons qui se rejoignent au centre avec un léger jeu — un sur
/// trois en accent. Rotation continue 0,22 rad/s, respiration globale
/// ±3 % à 0,65 Hz, écartement individuel des paires. Purement décorative :
/// pose statique si la réduction d'animations système est active.
class DnaHelix extends StatefulWidget {
  const DnaHelix({this.height = 140, super.key});

  final double height;

  @override
  State<DnaHelix> createState() => _DnaHelixState();
}

class _DnaHelixState extends State<DnaHelix>
    with SingleTickerProviderStateMixin {
  // Un tour complet à 0,22 rad/s : ~28,6 s par cycle.
  static const _cycle = Duration(milliseconds: 28560);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Préférence système : animation en boucle, ou pose statique.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Animation décorative : double hélice d’ADN',
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _DnaHelixPainter(
                  time: _controller.value * _cycle.inMilliseconds / 1000.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DnaHelixPainter extends CustomPainter {
  const _DnaHelixPainter({required this.time});

  /// Temps absolu (secondes) — pilote rotation, respiration et pulsations.
  final double time;

  static const int _samples = 96;
  static const double _turns = 2.4;
  static const int _rungs = 26;
  static const double _radius = 1.32;
  static const double _halfHeight = 4.7; // H 9,4

  @override
  void paint(Canvas canvas, Size size) {
    final rotation = time * 0.22;
    final breathe = 1 + 0.03 * math.sin(time * 2 * math.pi * 0.65);
    final worldScale = size.height * 0.062 * breathe;
    const focal = 13.0;

    // Cadrage hero : légère inclinaison rotation.z = 0,16.
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(0.16);
    canvas.translate(-size.width / 2, -size.height / 2);

    final elements = <({double depth, void Function(Canvas) draw})>[];

    (Offset, double) strandPoint(double s, double phase) {
      final theta = 2 * math.pi * _turns * s + rotation + phase;
      final x = _radius * math.cos(theta);
      final z = _radius * math.sin(theta);
      final y = _halfHeight * (2 * s - 1);
      return (
        project(x, -y, z, focal: focal, size: size, worldScale: worldScale),
        z,
      );
    }

    void addStrand(Color color, double phase) {
      for (var i = 0; i < _samples; i++) {
        final (from, depthFrom) = strandPoint(i / _samples, phase);
        final (to, depthTo) = strandPoint((i + 1) / _samples, phase);
        final depth = (depthFrom + depthTo) / 2;
        final near = (depth / _radius + 1) / 2;
        final paint = Paint()
          ..color = color.withValues(alpha: 0.24 + 0.56 * near)
          ..strokeWidth = size.height * 0.012 * (0.75 + 0.65 * near)
          ..strokeCap = StrokeCap.round;
        elements.add(
          (depth: depth, draw: (canvas) => canvas.drawLine(from, to, paint)),
        );
      }
    }

    // Barreaux : deux demi-bâtons avec un jeu central (liaison hydrogène),
    // un sur trois en accent ; écartement individuel des paires.
    for (var rungIndex = 0; rungIndex < _rungs; rungIndex++) {
      final s = (rungIndex + 0.5) / _rungs;
      final pulse = 0.5 + 0.5 * math.sin(time * 1.4 - rungIndex * 0.7 - s * 4);
      final spread = 0.985 + pulse * 0.03;
      final theta = 2 * math.pi * _turns * s + rotation;
      final y = -_halfHeight * (2 * s - 1);

      Offset at(double factor, double phase) {
        final x = _radius * spread * factor * math.cos(theta + phase);
        final z = _radius * spread * factor * math.sin(theta + phase);
        return project(
          x,
          y,
          z,
          focal: focal,
          size: size,
          worldScale: worldScale,
        );
      }

      final depth = 0.0 +
          (_radius * math.sin(theta) + _radius * math.sin(theta + math.pi)) / 2;
      final facing = math.cos(theta).abs();
      final color = rungIndex % 3 == 0
          ? AppColors.accent
          : AppColors.neutralBadgeText.withValues(alpha: 0.8);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.18 + 0.5 * facing)
        ..strokeWidth = size.height * 0.008
        ..strokeCap = StrokeCap.round;
      final beadPaint = Paint()
        ..color = color.withValues(alpha: 0.55 * (0.4 + 0.6 * facing));

      elements.add(
        (
          depth: depth - 0.02,
          draw: (canvas) {
            // Demi-bâton de chaque brin vers le centre, avec un jeu.
            canvas.drawLine(at(1, 0), at(0.08, 0), paint);
            canvas.drawLine(at(1, math.pi), at(0.08, math.pi), paint);
            // Billes d'ancrage discrètes — jamais des perles.
            canvas.drawCircle(at(1, 0), size.height * 0.006, beadPaint);
            canvas.drawCircle(at(1, math.pi), size.height * 0.006, beadPaint);
          },
        ),
      );
    }

    addStrand(AppColors.primary, 0);
    addStrand(AppColors.primaryLight, math.pi);

    elements.sort((a, b) => a.depth.compareTo(b.depth));
    for (final element in elements) {
      element.draw(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DnaHelixPainter oldDelegate) => oldDelegate.time != time;
}
