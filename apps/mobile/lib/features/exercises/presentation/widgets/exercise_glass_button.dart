import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Bouton rond « en verre » posé sur le média de la fiche (maquette 2e) :
/// 40×40, rayon 14, fond assombri + flou, bordure fine.
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

  static const double _size = 40;
  static const double _iconSize = 20;
  static const double _blur = 12;
  static const double _backgroundAlpha = 0.7;
  static const BorderRadius _radius = AppRadius.lgAll;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: Material(
            color: AppColors.darkSurface.withValues(alpha: _backgroundAlpha),
            child: InkWell(
              onTap: onPressed,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
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
    );
  }
}
