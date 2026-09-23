import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

/// Jauge linéaire de la refonte : piste blanche .07, remplissage plein,
/// coins stadium. Hauteur 6 en carte, 3 en tuile.
class AppGauge extends StatelessWidget {
  const AppGauge({
    required this.progress,
    required this.color,
    this.height = 6,
    this.gradient,
    super.key,
  });

  /// Progression 0..1 (valeurs hors bornes écrêtées).
  final double progress;
  final Color color;
  final double height;

  /// Remplissage en dégradé, à la place de [color] quand il est donné —
  /// `AppColors.violetRamp`, qui s'éclaircit dans le sens de la progression.
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.gaugeTrack),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: gradient == null ? color : null,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
