import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// LA FRAPPE.
///
/// Une récompense fraîchement obtenue ne s'affiche pas : elle SE GRAVE. Le
/// sceau arrive trop grand et se resserre d'un coup sec, et l'onde de la
/// frappe s'échappe derrière lui. C'est le seul moment où l'application se
/// permet une célébration, et elle ne dure qu'une seconde.
///
/// Elle ne rejoue jamais. Une gravure qui se rejouerait à chaque ouverture
/// perdrait exactement ce qui en fait le prix : elle marque un instant, pas
/// un état. C'est le journal des récompenses qui en décide.
///
/// La réduction d'animations système est respectée : le sceau est alors
/// simplement là, entier, sans mouvement.
class EngravedSeal extends StatefulWidget {
  const EngravedSeal({
    required this.child,
    required this.engrave,
    super.key,
  });

  final Widget child;

  /// Obtenue à l'instant : elle se grave. Sinon elle est simplement là.
  final bool engrave;

  /// La gravure dure ce que dure le remplissage d'un anneau : un seul tempo
  /// pour tout ce qui « apparaît » à l'ouverture.
  static const Duration engraveDuration = AppMotion.ring;

  /// Part de l'animation consacrée au RESSERREMENT. Le reste laisse l'onde
  /// finir de s'échapper.
  static const double strikeShare = 0.62;

  @override
  State<EngravedSeal> createState() => _EngravedSealState();
}

class _EngravedSealState extends State<EngravedSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: EngravedSeal.engraveDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.engrave) {
      _controller.value = 1;
      return;
    }
    _controller.duration =
        AppMotion.resolve(context, EngravedSeal.engraveDuration);
    if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.engrave) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final strike = (progress / EngravedSeal.strikeShare).clamp(0.0, 1.0);
        final eased = AppMotion.emphasized.transform(strike);
        return CustomPaint(
          painter: StrikeWave(progress: progress),
          child: Opacity(
            // L'opacité se ferme AVANT le resserrement : le sceau doit être
            // entier au moment où il se pose, pas transparent.
            opacity: (strike * 2).clamp(0.0, 1.0),
            child: Transform.scale(scale: 1.18 - 0.18 * eased, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// L'onde de la frappe : un anneau qui s'échappe et s'éteint.
///
/// Public pour les tests : l'avancement de la gravure est la seule chose
/// qu'ils peuvent lire, un dessin ne se relit pas autrement.
@visibleForTesting
class StrikeWave extends CustomPainter {
  const StrikeWave({required this.progress});

  final double progress;

  /// L'onde ne part qu'une fois le sceau presque posé.
  static const double _start = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= _start) return;
    final wave = ((progress - _start) / (1 - _start)).clamp(0.0, 1.0);
    final radius = size.shortestSide * (0.5 + 0.45 * wave);
    canvas.drawCircle(
      size.center(Offset.zero),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - wave)
        ..color = AppColors.primaryLight.withValues(alpha: 0.6 * (1 - wave)),
    );
  }

  @override
  bool shouldRepaint(StrikeWave old) => old.progress != progress;
}
