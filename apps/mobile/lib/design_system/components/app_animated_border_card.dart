import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../motion/app_motion.dart';
import '../radius/app_radius.dart';

/// Carte à bordure animée (offre populaire) : le contour violet EST le
/// tracé, avec un segment accent de 84 px qui parcourt le périmètre en
/// 3,4 s. Statique si la réduction d'animations système est active.
class AppAnimatedBorderCard extends StatefulWidget {
  const AppAnimatedBorderCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  State<AppAnimatedBorderCard> createState() => _AppAnimatedBorderCardState();
}

class _AppAnimatedBorderCardState extends State<AppAnimatedBorderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        AppMotion.resolve(context, const Duration(milliseconds: 3400)) ==
            Duration.zero;
    if (reduced) {
      _controller.stop();
      _controller.value = 0.15;
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        foregroundPainter: _DashBorderPainter(progress: _controller.value),
        child: child,
      ),
      // Le contenu de la carte a sa propre couche : la bordure repeint à
      // chaque image, le contenu (textes, prix) n'est composé qu'une fois.
      child: RepaintBoundary(
        child: Container(
          padding: widget.padding,
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardSecondaryAll,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _DashBorderPainter extends CustomPainter {
  const _DashBorderPainter({required this.progress});

  final double progress;
  static const double _dashLength = 84;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(23.25),
    ).deflate(0.75);
    final path = Path()..addRRect(rrect);

    // Contour continu en primaryLight.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.primaryLightBorder,
    );

    // Segment accent qui parcourt le périmètre.
    for (final metric in path.computeMetrics()) {
      final start = progress * metric.length;
      final end = start + _dashLength;
      final segment = metric.extractPath(start, end.clamp(0, metric.length));
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent;
      canvas.drawPath(segment, paint);
      if (end > metric.length) {
        // Le segment boucle sur le début du tracé.
        canvas.drawPath(
          metric.extractPath(0, end - metric.length),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
