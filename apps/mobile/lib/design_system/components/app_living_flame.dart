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
/// Elle ne se montre QUE sur une série vivante : le parent la retire sinon
/// (`ConsistencyStreak`). Une flamme qui vacillerait sur une série éteinte
/// serait un contresens.
///
/// La réduction d'animations système est respectée : la flamme est alors
/// simplement dessinée, immobile.
class AppLivingFlame extends StatefulWidget {
  const AppLivingFlame({required this.size, required this.color, super.key});

  final double size;
  final Color color;

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
    if (duration == Duration.zero) {
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

  /// Respiration adoucie, puis échelle et lumière qui la suivent.
  late final Animation<double> _breath = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 1 + AppLivingFlame.amplitude,
  ).animate(_breath);

  /// La lumière suit l'échelle : une flamme qui grandit sans s'éclaircir a
  /// l'air d'un zoom, pas d'un feu.
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.82,
    end: 1,
  ).animate(_breath);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Seule la COUCHE bouge : `FadeTransition` ne repeint pas l'icône, il
    // change l'alpha de sa couche, et la frontière de repeinture garde le
    // reste de l'accueil hors de chaque image. Un `AnimatedBuilder` autour
    // d'un `Opacity` repeignait l'icône ET remontait jusqu'à la liste
    // entière, 60 fois par seconde (`app_living_flame_test.dart`).
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scale,
        child: FadeTransition(
          opacity: _opacity,
          child: Icon(AppIcons.streak, size: widget.size, color: widget.color),
        ),
      ),
    );
  }
}
