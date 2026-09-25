import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';
import 'app_card.dart';
import 'app_section_label.dart';

/// Une carte À TITRE : une icône et un titre en capitales violettes, puis
/// son contenu (« QUANTITÉ », « VALEURS NUTRITIONNELLES »).
///
/// [trailing] se pose à droite du titre (les pastilles d'unité de la
/// quantité) quand la largeur le permet, et passe SOUS lui sinon : sur 320
/// points ou avec un texte agrandi, un titre et quatre pastilles ne tiennent
/// pas sur une rangée, et rien ne doit y déborder.
class AppTitledCard extends StatelessWidget {
  const AppTitledCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  static const double _iconSize = 16;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _iconSize, color: AppColors.primaryLight),
        const SizedBox(width: AppSpacing.xs),
        // Un nœud À PART : sans `container`, le drapeau « titre » et son
        // libellé se fondaient dans le nœud voisin — le champ Quantité
        // s'annonçait comme un titre, et la navigation par titres lisait
        // toute la liste des aliments d'un bloc.
        Flexible(
          child: Semantics(
            header: true,
            container: true,
            child: AppSectionLabel(title),
          ),
        ),
      ],
    );
    final extra = trailing;
    return AppCard(
      // Un GROUPE, dont chaque pièce garde son nœud : le titre d'abord, puis
      // le contenu dans l'ordre. Sans quoi un texte d'aide se fondait dans le
      // champ voisin, lu avant le titre de sa propre carte.
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (extra == null)
              heading
            else
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                children: [heading, extra],
              ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
