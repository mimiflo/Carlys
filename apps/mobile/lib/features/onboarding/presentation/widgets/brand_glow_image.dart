import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Image détourée accompagnée de lueurs qui épousent SA SILHOUETTE.
///
/// Équivalent du `filter: drop-shadow(...)` de la référence. Une `BoxShadow`
/// ne conviendrait pas : elle dessine l'ombre du CADRE, ce qui donne un
/// rectangle coloré derrière une image détourée. Une lueur fidèle est une
/// copie floutée et teintée de l'image elle-même, posée dessous — elle suit
/// donc le canal alpha.
///
/// Chaque lueur est un couple (couleur, écart-type du flou). Les rayons de la
/// référence sont des `blur-radius` CSS : l'écart-type gaussien en vaut la
/// moitié.
class BrandGlowImage extends StatelessWidget {
  const BrandGlowImage({
    required this.image,
    required this.glows,
    this.expand = false,
    super.key,
  });

  /// L'image, déjà dimensionnée. La même instance sert aux copies floutées.
  final Widget image;

  final List<(Color, double)> glows;

  /// `true` quand la pile doit remplir son parent (photographie plein cadre),
  /// `false` quand elle prend la taille de l'image (sceau).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: expand ? StackFit.expand : StackFit.loose,
      // Les lueurs débordent de l'image : les rogner les transformerait en
      // bandeaux à bord franc.
      clipBehavior: Clip.none,
      children: [
        for (final (color, sigma) in glows)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                child: image,
              ),
            ),
          ),
        image,
      ],
    );
  }
}
