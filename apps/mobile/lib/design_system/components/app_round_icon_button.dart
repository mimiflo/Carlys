import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';

/// Un bouton-disque d'en-tête : une icône sur un disque de surface, cerclé
/// d'un filet — le rouage du profil, la loupe et les amis de la Communauté.
///
/// La cible tactile est [AppSpacing.touchTarget], le disque lui-même : pas
/// d'ornement plus petit que la zone qui répond au doigt.
class AppRoundIconButton extends StatelessWidget {
  const AppRoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.primaryLight,
    this.isActive = false,
    super.key,
  });

  final IconData icon;

  /// Ce que le lecteur d'écran annonce, et l'infobulle d'un appui long.
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  /// Un bouton qui BASCULE (la loupe) se dit enfoncé tant que son mode dure :
  /// le disque passe au violet, et le lecteur d'écran l'annonce sélectionné.
  final bool isActive;

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isActive,
      child: Material(
        color: isActive ? AppColors.primaryBadgeBg : AppColors.darkSurface,
        shape: CircleBorder(
          side: BorderSide(
            color: isActive
                ? AppColors.primaryBadgeBorder
                : AppColors.darkBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: const BoxConstraints.tightFor(
            width: AppSpacing.touchTarget,
            height: AppSpacing.touchTarget,
          ),
          icon: Icon(icon, size: _iconSize, color: color),
        ),
      ),
    );
  }
}
