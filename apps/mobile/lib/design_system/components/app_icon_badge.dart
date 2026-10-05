import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

/// Une icône sur un disque teinté de sa couleur : l'agenda d'une carte de
/// programme, la coche verte de « 1 Faite », le tiret rouge de « 0 Manquée ».
///
/// Décoratif : l'icône répète le libellé qui l'accompagne, le lecteur
/// d'écran ne la lit donc pas.
class AppIconBadge extends StatelessWidget {
  const AppIconBadge({
    required this.icon,
    this.color = AppColors.primaryLight,
    this.background = AppColors.primaryBadgeBg,
    this.size = 48,
    super.key,
  });

  final IconData icon;
  final Color color;
  final Color background;

  /// Le diamètre du disque ; l'icône en prend un peu moins de la moitié.
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.46, color: color),
      ),
    );
  }
}
