import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/progression.dart';

/// LA MAJESTÉ, PALIER PAR PALIER.
///
/// Plus le titre monte, plus la mise en scène s'enrichit : le liseré
/// s'épaissit, le dégradé de marque apparaît, un halo se pose, et l'écrin
/// finit par respirer. Rien de tout cela n'est décoratif au hasard — chaque
/// cran doit se VOIR, sinon monter d'un titre ne se ressent pas.
///
/// La règle qui la gouverne : la majesté suit le titre le plus haut JAMAIS
/// atteint, pas le titre courant. Personne ne doit voir son écran se ternir
/// parce qu'il a été malade deux semaines.
class TitleRegalia {
  const TitleRegalia({
    required this.border,
    required this.borderWidth,
    required this.glow,
    required this.crowned,
    required this.gradient,
  });

  /// Couleur du liseré de l'écrin.
  final Color border;
  final double borderWidth;

  /// Rayon du halo, en pixels. Zéro aux premiers paliers : un halo dès le
  /// premier titre ne laisserait plus rien à gagner.
  final double glow;

  /// Le dernier palier porte sa marque : une couronne discrète.
  final bool crowned;

  /// Dégradé du nom du titre. Sobre au début, de marque ensuite.
  final Gradient gradient;

  static const Gradient _plain = LinearGradient(
    colors: [AppColors.darkTextPrimary, AppColors.darkTextPrimary],
  );

  /// L'écrin d'un titre.
  static TitleRegalia of(CarlysTitle title) => switch (title) {
        // Apprenti : rien de plus qu'une carte. C'est le point de départ, et
        // il doit avoir l'air d'un point de départ.
        CarlysTitle.apprenti => const TitleRegalia(
            border: AppColors.darkBorder,
            borderWidth: 1,
            glow: 0,
            crowned: false,
            gradient: _plain,
          ),
        // Architecte : le violet entre.
        CarlysTitle.architecte => const TitleRegalia(
            border: AppColors.primaryLightBorder,
            borderWidth: 1,
            glow: 0,
            crowned: false,
            gradient: _plain,
          ),
        // Artisan : le nom prend le dégradé de marque.
        CarlysTitle.artisan => const TitleRegalia(
            border: AppColors.primaryLightBorder,
            borderWidth: 1.5,
            glow: 12,
            crowned: false,
            gradient: AppColors.signature,
          ),
        // Maître : le halo s'ouvre.
        CarlysTitle.maitre => const TitleRegalia(
            border: AppColors.primary,
            borderWidth: 2,
            glow: 22,
            crowned: false,
            gradient: AppColors.signature,
          ),
        // Icône : couronné.
        CarlysTitle.icone => const TitleRegalia(
            border: AppColors.primary,
            borderWidth: 2.5,
            glow: 34,
            crowned: true,
            gradient: AppColors.signature,
          ),
      };

  /// Décoration de l'écrin. Le halo est une OMBRE, jamais un fond : posé en
  /// fond, il grisaillerait la carte au lieu de la faire rayonner.
  BoxDecoration get decoration => BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: border, width: borderWidth),
        boxShadow: glow <= 0
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryHalo,
                  blurRadius: glow,
                  spreadRadius: glow / 6,
                ),
              ],
      );
}
