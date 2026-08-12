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
      duration: AppDashBorderPainter.travelDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        AppMotion.resolve(context, AppDashBorderPainter.travelDuration) ==
            Duration.zero;
    if (reduced) {
      _controller.stop();
      _controller.value = AppDashBorderPainter.restProgress;
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
        foregroundPainter: AppDashBorderPainter(progress: _controller.value),
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

/// Bordure au segment voyageur : le contour violet léger EST le tracé, un
/// segment accent de 84 px en fait le tour. Public pour être partagé — la
/// carte d'abonnement populaire et le profil Carlys ACTUEL parlent la même
/// langue visuelle.
class AppDashBorderPainter extends CustomPainter {
  const AppDashBorderPainter({
    required this.progress,
    this.cornerRadius = 24,
  });

  /// Un tour complet du périmètre.
  static const Duration travelDuration = Duration(milliseconds: 3400);

  /// Position de repos (réduction d'animations) : le segment reste visible,
  /// posé sur le flanc, sans jamais bouger.
  static const double restProgress = 0.15;

  final double progress;

  /// Rayon d'angle du CADRE entouré (le trait se centre dessus).
  final double cornerRadius;

  static const double _dashLength = 84;
  static const double _strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(cornerRadius - _strokeWidth / 2),
    ).deflate(_strokeWidth / 2);
    final path = Path()..addRRect(rrect);

    // Contour continu en primaryLight.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = AppColors.primaryLightBorder,
    );

    // Segment accent qui parcourt le périmètre.
    for (final metric in path.computeMetrics()) {
      final start = progress * metric.length;
      final end = start + _dashLength;
      final segment = metric.extractPath(start, end.clamp(0, metric.length));
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
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
  bool shouldRepaint(AppDashBorderPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.cornerRadius != cornerRadius;
}
