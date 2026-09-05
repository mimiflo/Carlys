import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Bouton rond « en verre » posé sur le média de la fiche (maquette 2e) :
/// ornement 40×40, rayon 14, fond assombri + flou, bordure fine — dans la
/// boîte tactile du design system, centrée sur lui.
class ExerciseGlassButton extends StatelessWidget {
  const ExerciseGlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  /// Taille de l'ORNEMENT, ce qui se voit. La zone qui répond au doigt est
  /// [AppSpacing.touchTarget], centrée dessus : un ornement de 40 sous un
  /// pouce n'est pas une cible, c'est un point.
  static const double ornamentSize = 40;

  /// Ce qui sépare le bord de la boîte tactile du bord de l'ornement. Un
  /// appelant qui pose le bouton au pixel près (coin d'un média) le
  /// retranche de sa position pour que l'ornement ne bouge pas.
  static const double inset = (AppSpacing.touchTarget - ornamentSize) / 2;

  static const double _iconSize = 20;
  static const double _blur = 12;
  static const double _backgroundAlpha = 0.7;
  static const BorderRadius _radius = AppRadius.lgAll;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: AppSpacing.touchTarget,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: _radius,
            child: Center(
              child: ClipRRect(
                borderRadius: _radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
                  child: Container(
                    width: ornamentSize,
                    height: ornamentSize,
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface.withValues(
                        alpha: _backgroundAlpha,
                      ),
                      borderRadius: _radius,
                      border: Border.all(color: AppColors.darkBorderStrong),
                    ),
                    child: Icon(
                      icon,
                      size: _iconSize,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
