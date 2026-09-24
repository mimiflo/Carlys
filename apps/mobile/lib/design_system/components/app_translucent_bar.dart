import 'dart:ui';

import 'package:flutter/widgets.dart';

import '../colors/app_colors.dart';
import '../theme/app_dark_theme.dart';

/// LE VERRE DÉPOLI DES BARRES BASSES — la recette, à un seul endroit.
///
/// Trois barres d'action la déclaraient chacune pour soi : celle de la fiche
/// d'exercice, celle de la séance en cours, celle de l'éditeur de modèle.
/// Toutes les trois écrivaient exactement la même chose — un `ClipRect`, un
/// `BackdropFilter` à 20, un fond `darkBackground` à 0,9, une bordure haute
/// d'un pixel — chacune derrière son propre `_blur` et son propre
/// `_veilAlpha`. Trois copies d'une même recette finissent par diverger :
/// l'une se corrige, les autres restent.
///
/// **Le `ClipRect` n'est pas décoratif.** Sans lui, `BackdropFilter` floute
/// TOUT ce qui est derrière lui dans la couche, pas seulement la surface de
/// la barre : l'écran entier se voilait. C'est l'oubli classique, et c'est
/// pourquoi il est ici plutôt que dans chaque appelant.
///
/// Ce composant ne pose ni marge intérieure ni zone sûre : la respiration
/// diffère réellement d'une barre à l'autre (l'une veut `SafeArea`, l'autre
/// ajoute l'encoche à son propre padding bas). Il ne tient que le verre —
/// et le thème qui va avec : le verre est sombre sous tous les réglages, et
/// son contenu prend le thème SOMBRE ([AppDarkTheme]). Sous le thème Clair,
/// l'appel à l'action désactivé de l'éditeur y posait sinon une plaque
/// BLANCHE, et le bouton texte voisin le violet pensé pour une page claire.
class AppTranslucentBar extends StatelessWidget {
  const AppTranslucentBar({required this.child, this.color, super.key});

  /// Le contenu de la barre, posé sur le verre.
  final Widget child;

  /// Fond du verre. Par défaut le fond sombre à 0,9 — la barre de navigation,
  /// elle, en a un plus dense, relevé au pixel sur la maquette.
  final Color? color;

  /// Rayon de flou du fond. Une seule valeur dans toute l'application ; elle
  /// est ici pour être nommée, pas pour être réglée.
  static const double blur = 20;

  /// Opacité du voile posé sur le fond sombre.
  static const double veilAlpha = 0.9;

  /// Épaisseur du trait qui sépare la barre du contenu.
  ///
  /// Nommée parce qu'un appelant peut avoir à la RÉCUPÉRER en marge : ce
  /// composant peint avec `DecoratedBox`, qui n'ajoute rien autour de son
  /// enfant, là où `Container` posait `decoration.padding` tout seul. La
  /// barre de navigation, qui venait d'un `Container`, la repose donc
  /// explicitement — sans quoi ses onglets remontent d'un pixel.
  static const double borderWidth = 1;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                color ?? AppColors.darkBackground.withValues(alpha: veilAlpha),
            border: const Border(
              top: BorderSide(color: AppColors.darkBorder, width: borderWidth),
            ),
          ),
          child: AppDarkTheme(child: child),
        ),
      ),
    );
  }
}
