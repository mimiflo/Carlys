import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Bouton pleine largeur au **dégradé de marque**.
///
/// Réservé aux surfaces de marque, où le lime de l'application n'a pas encore
/// de sens : sur la page de bienvenue, c'est l'identité qu'on montre, pas
/// l'interface. Ailleurs, l'action principale reste [AppButton] en accent —
/// deux boutons « principaux » de couleurs différentes dans un même écran
/// annuleraient la hiérarchie.
class AppBrandButton extends StatelessWidget {
  const AppBrandButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  /// Géométrie : hauteur confortable au pouce, libellé en majuscules espacées.
  static const double _height = 58;
  static const double _tracking = 1.4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.fullAll,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadius.fullAll,
            child: Ink(
              height: _height,
              decoration: const BoxDecoration(
                gradient: AppColors.signature,
                borderRadius: AppRadius.fullAll,
              ),
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    label.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subheading.copyWith(
                      color: AppColors.neutral0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: _tracking,
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
