import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../typography/app_typography.dart';

/// L'avatar d'une personne : l'initiale de son prénom sur un disque.
///
/// Carlys n'a PAS de photo de profil — ni champ, ni envoi, ni modération —
/// et en afficher une serait inventer une donnée. L'initiale est donc
/// l'avatar de tout le monde, partout où un visage est attendu.
///
/// Deux tons : [highlighted] faux, le dégradé violet des autres ; vrai,
/// la personne elle-même — un disque sombre cerclé de violet, comme sur la
/// maquette du classement, pour se reconnaître d'un coup d'œil.
class AppInitialAvatar extends StatelessWidget {
  const AppInitialAvatar({
    required this.name,
    this.size = 40,
    this.highlighted = false,
    super.key,
  });

  final String name;
  final double size;
  final bool highlighted;

  /// L'initiale affichée : la première lettre, en capitale ; « ? » pour un
  /// prénom vide, plutôt qu'un disque muet.
  static String initialOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: highlighted ? null : AppColors.violetRamp,
          color: highlighted ? AppColors.darkSurface : null,
          border: highlighted
              ? const Border.fromBorderSide(
                  BorderSide(color: AppColors.primary, width: 1.5),
                )
              : null,
        ),
        child: Text(
          initialOf(name),
          style: AppTypography.resized(
            AppTypography.subheading,
            size * 0.4,
          ).copyWith(color: AppColors.neutral0, height: 1),
        ),
      ),
    );
  }
}
