import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Double hélice d'ADN en rotation continue — animation d'ambiance de l'écran
/// nutrition. Purement décorative : elle respecte la réduction d'animations
/// système (pose statique) et reste isolée dans un [RepaintBoundary].
class DnaHelix extends StatefulWidget {
  const DnaHelix({this.height = 140, super.key});

  final double height;

  @override
  State<DnaHelix> createState() => _DnaHelixState();
}

class _DnaHelixState extends State<DnaHelix>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.ambient);
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
    final colorScheme = Theme.of(context).colorScheme;
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
                  phase: _controller.value * 2 * math.pi,
                  strandA: colorScheme.primary,
                  strandB: AppColors.accent,
                  rung: colorScheme.outlineVariant,
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
  const _DnaHelixPainter({
    required this.phase,
    required this.strandA,
    required this.strandB,
    required this.rung,
  });

  /// Angle de rotation courant de l'hélice, en radians.
  final double phase;
  final Color strandA;
  final Color strandB;
  final Color rung;

  static const int _samples = 60;
  static const int _rungEvery = 5;
  static const double _turns = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final amplitude = size.height * 0.34;
    final baseRadius = size.height * 0.035;

    // Chaque élément porte sa profondeur : l'arrière se dessine d'abord.
    final elements = <({double depth, void Function(Canvas) draw})>[];

    Offset pointAt(int index, double strandPhase) {
      final x = size.width * index / _samples;
      final theta =
          2 * math.pi * _turns * index / _samples + phase + strandPhase;
      return Offset(x, centerY + amplitude * math.sin(theta));
    }

    double depthAt(int index, double strandPhase) {
      final theta =
          2 * math.pi * _turns * index / _samples + phase + strandPhase;
      return math.cos(theta);
    }

    void addStrand(Color color, double strandPhase) {
      for (var i = 0; i < _samples; i++) {
        final from = pointAt(i, strandPhase);
        final to = pointAt(i + 1, strandPhase);
        final depth =
            (depthAt(i, strandPhase) + depthAt(i + 1, strandPhase)) / 2;
        final near = (depth + 1) / 2;
        final paint = Paint()
          ..color = color.withValues(alpha: 0.30 + 0.70 * near)
          ..strokeWidth = baseRadius * (0.9 + 0.8 * near)
          ..strokeCap = StrokeCap.round;
        elements.add(
          (depth: depth, draw: (canvas) => canvas.drawLine(from, to, paint)),
        );
        if (i % _rungEvery == 2) {
          final node = pointAt(i, strandPhase);
          final nodeDepth = depthAt(i, strandPhase);
          final nodeNear = (nodeDepth + 1) / 2;
          final nodePaint = Paint()
            ..color = color.withValues(alpha: 0.35 + 0.65 * nodeNear);
          final radius = baseRadius * (1.4 + 1.2 * nodeNear);
          elements.add(
            (
              depth: nodeDepth,
              draw: (canvas) => canvas.drawCircle(node, radius, nodePaint),
            ),
          );
        }
      }
    }

    // Barreaux entre les deux brins (paires de bases).
    for (var i = 0; i < _samples; i += _rungEvery) {
      final a = pointAt(i, 0);
      final b = pointAt(i, math.pi);
      final depth = (depthAt(i, 0) + depthAt(i, math.pi)) / 2;
      final near = (depthAt(i, 0).abs());
      // Un barreau vu de face (brins écartés) est plus visible que de profil.
      final paint = Paint()
        ..color = rung.withValues(alpha: 0.25 + 0.55 * near)
        ..strokeWidth = baseRadius * 0.8;
      elements.add(
        (depth: depth - 0.05, draw: (canvas) => canvas.drawLine(a, b, paint)),
      );
    }

    addStrand(strandA, 0);
    addStrand(strandB, math.pi);

    elements.sort((a, b) => a.depth.compareTo(b.depth));
    for (final element in elements) {
      element.draw(canvas);
    }
  }

  @override
  bool shouldRepaint(_DnaHelixPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.strandA != strandA ||
      oldDelegate.strandB != strandB ||
      oldDelegate.rung != rung;
}
