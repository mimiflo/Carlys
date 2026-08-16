import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../motion/app_motion.dart';

/// LA FLAMME QUI VIT.
///
/// Une série de constance qui tient est la seule chose de l'accueil qui
/// mérite de bouger en permanence : c'est un feu entretenu, pas un état. Le
/// mouvement est volontairement ténu — une respiration d'échelle et de
/// lumière, jamais un clignotement.
///
/// Elle ne s'anime QUE si la série est vivante. Une flamme qui vacillerait
/// sur une série éteinte serait un contresens, et un mouvement permanent
/// sans raison coûterait du budget de rendu pour rien.
///
/// La réduction d'animations système est respectée : la flamme est alors
/// simplement dessinée, immobile.
class AppLivingFlame extends StatefulWidget {
  const AppLivingFlame({
    required this.size,
    required this.color,
    this.alive = true,
    super.key,
  });

  final double size;
  final Color color;

  /// La série est en cours. Faux, la flamme ne bouge pas.
  final bool alive;

  /// Respiration complète. Lente : un feu ne palpite pas.
  static const Duration breath = Duration(milliseconds: 2200);

  /// Amplitude de la respiration, en fraction de taille.
  static const double amplitude = 0.10;

  @override
  State<AppLivingFlame> createState() => _AppLivingFlameState();
}

class _AppLivingFlameState extends State<AppLivingFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppLivingFlame.breath,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = AppMotion.resolve(context, AppLivingFlame.breath);
    if (!widget.alive || duration == Duration.zero) {
      _controller
        ..stop()
        ..value = 0;
      return;
    }
    _controller.duration = duration;
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AppLivingFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alive != oldWidget.alive) didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(AppIcons.streak, size: widget.size, color: widget.color);
    if (!widget.alive) return icon;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final breath = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1 + AppLivingFlame.amplitude * breath,
          child: Opacity(
            // La lumière suit l'échelle : une flamme qui grandit sans
            // s'éclaircir a l'air d'un zoom, pas d'un feu.
            opacity: 0.82 + 0.18 * breath,
            child: child,
          ),
        );
      },
      child: icon,
    );
  }
}
