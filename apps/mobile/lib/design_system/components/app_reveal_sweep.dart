import 'package:flutter/material.dart';

import '../motion/app_motion.dart';

/// LA LIGNE QUI SE DESSINE.
///
/// Découvre son enfant de la gauche vers la droite, une fois, à l'affichage.
/// Sur un graphique, cela donne exactement le geste attendu : la courbe se
/// trace dans le sens du temps, du plus ancien vers aujourd'hui.
///
/// Le tracé est un CLIP, pas une reconstruction : le graphique est peint une
/// seule fois et c'est la fenêtre qui s'ouvre. Redessiner la courbe à chaque
/// image coûterait soixante reconstructions pour le même résultat.
///
/// La réduction d'animations système est respectée : l'enfant est alors
/// simplement là, entier.
class AppRevealSweep extends StatefulWidget {
  const AppRevealSweep({
    required this.child,
    this.duration = AppMotion.deliberate,
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppRevealSweep> createState() => _AppRevealSweepState();
}

class _AppRevealSweepState extends State<AppRevealSweep> {
  double _factor = 0;

  @override
  void initState() {
    super.initState();
    // Après la première image : la fenêtre part fermée et s'ouvre.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _factor = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _factor),
        duration: AppMotion.resolve(context, widget.duration),
        curve: AppMotion.standard,
        builder: (context, value, child) => ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            // Jamais tout à fait zéro : une largeur nulle ferait disparaître
            // la contrainte, et l'enfant se peindrait à une taille libre.
            widthFactor: value.clamp(0.001, 1),
            child: child,
          ),
        ),
        // Largeur figée : sans elle, l'enfant se rétrécirait avec la
        // fenêtre au lieu d'être découvert.
        child: SizedBox(width: constraints.maxWidth, child: widget.child),
      ),
    );
  }
}
