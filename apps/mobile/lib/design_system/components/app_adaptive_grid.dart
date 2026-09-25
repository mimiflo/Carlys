import 'package:flutter/material.dart';

import '../spacing/app_spacing.dart';

/// Une GRILLE qui choisit elle-même son nombre de colonnes.
///
/// Quatre tuiles côte à côte sur un téléphone de 393 points (les valeurs
/// d'un repas, les moments de la journée), mais deux par rangée sur 320
/// points, et une seule quand le texte est agrandi au double : une rangée
/// fixe de quatre y ferait déborder chaque libellé. La largeur minimale
/// d'une cellule est donc donnée en points de TEXTE, et grandit avec le
/// réglage de taille de l'appareil.
///
/// Les colonnes divisent le nombre de cellules quand c'est possible : trois
/// colonnes pour quatre tuiles laisseraient une orpheline sur la seconde
/// rangée, deux en font un carré. Les cellules d'une même rangée prennent
/// la hauteur de la plus haute.
///
/// Aucun enfant ne doit demander sa largeur par un `LayoutBuilder` : la
/// rangée mesure ses cellules par leur hauteur intrinsèque, que ce widget ne
/// sait pas donner.
class AppAdaptiveGrid extends StatelessWidget {
  const AppAdaptiveGrid({
    required this.children,
    required this.minItemWidth,
    this.spacing = AppSpacing.xs,
    super.key,
  });

  final List<Widget> children;

  /// La largeur en dessous de laquelle une cellule ne descend pas, au
  /// réglage de texte NORMAL ; le facteur de l'appareil l'agrandit.
  final double minItemWidth;

  /// L'écart entre deux cellules, en largeur comme en hauteur.
  final double spacing;

  /// Le nombre de colonnes pour [count] cellules dans [width] points.
  ///
  /// Public pour être éprouvé seul : c'est toute la règle de la grille.
  static int columnsFor({
    required double width,
    required double minItemWidth,
    required double spacing,
    required int count,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    if (count <= 1) {
      return 1;
    }
    final needed = textScaler.scale(minItemWidth);
    final fit = ((width + spacing) / (needed + spacing)).floor().clamp(
      1,
      count,
    );
    for (var columns = fit; columns > 1; columns--) {
      if (count % columns == 0) {
        return columns;
      }
    }
    return fit;
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          width: constraints.maxWidth,
          minItemWidth: minItemWidth,
          spacing: spacing,
          count: children.length,
          textScaler: textScaler,
        );
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: spacing));
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) SizedBox(width: spacing),
                    Expanded(
                      child: start + column < children.length
                          ? children[start + column]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
