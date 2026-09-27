import 'package:flutter/material.dart';

import '../../../../core/explanations/explanation_sheet.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/nutrition_explanations.dart';

/// Bas du hero « métabolisme » : dépense totale à gauche, décomposition
/// MB / activité à droite.
///
/// Les deux blocs ouvrent leur POURQUOI. C'est le chiffre le plus gros de
/// l'application, et le plus mal compris : ce n'est pas une mesure, c'est une
/// estimation tirée d'un facteur d'activité que l'utilisateur a lui-même
/// déclaré. Le dire au moment où on le lit vaut mieux que de le laisser
/// croire pendant trois semaines.
class MetabolismExpenditureRow extends StatelessWidget {
  const MetabolismExpenditureRow({required this.metabolism, super.key});

  final MetabolismResult metabolism;

  @override
  Widget build(BuildContext context) {
    // « 2 759 » — séparateur de milliers commun à toute l'app.
    final total = formatThousands(metabolism.tdeeKcal);
    final bmr = formatThousands(metabolism.bmrKcal);
    // Activité = dépense totale − métabolisme de base : aucune valeur inventée.
    final activity = formatThousands(metabolism.tdeeKcal - metabolism.bmrKcal);

    final depense = AppExplainable(
      enonce: 'Dépense totale $total kilocalories',
      onExplain: () =>
          showExplanation(context, NutritionExplanations.depenseEnergetique),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Le chiffre sur UNE ligne, qui se resserre plutôt que de se
          // couper (« 2 75 / 9 » en texte ×2).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              total,
              maxLines: 1,
              softWrap: false,
              style: AppTypography.metricXL.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _LabelExplique('Kcal / dépense totale'),
        ],
      ),
    );
    final decomposition = AppExplainable(
      // « plus », jamais « dont » : l'activité est calculée comme
      // `tdee − bmr`, donc elle s'AJOUTE au métabolisme de base. Le
      // « dont » affirmait l'inverse au lecteur d'écran, alors que le
      // visuel, lui, décompose bien la dépense totale en deux parts.
      enonce:
          'Métabolisme de base $bmr kilocalories, '
          'plus $activity kilocalories d’activité',
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      onExplain: () =>
          showExplanation(context, NutritionExplanations.metabolismeDeBase),
      // Deux lignes de label font 30 points, 46 avec le rembourrage : la
      // hauteur minimale porte le bloc à la cible tactile.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.touchTarget - 2 * AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LabelExplique('MB $bmr', color: AppColors.darkTextTertiary),
            const SizedBox(height: AppSpacing.xxs),
            AppSectionLabel(
              'Activité $activity',
              color: AppColors.darkTextTertiary,
            ),
          ],
        ),
      ),
    );

    // Côte à côte quand ils tiennent, la décomposition SOUS la dépense
    // sinon : en texte agrandi, elle recouvrait « KCAL / DÉPENSE TOTALE ».
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [depense, decomposition],
      ),
    );
  }
}

/// Un label de section suivi du glyphe d'explication.
///
/// Le glyphe n'est qu'un ORNEMENT : il signale qu'il y a quelque chose à
/// ouvrir, c'est l'[AppExplainable] au-dessus qui prend le geste.
class _LabelExplique extends StatelessWidget {
  const _LabelExplique(this.texte, {this.color});

  final String texte;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final teinte = color;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flexible : en texte ×2 sur 320 points, « KCAL / DÉPENSE TOTALE »
        // est plus large que l'écran, et passe à la ligne.
        Flexible(
          child: teinte == null
              ? AppSectionLabel(texte)
              : AppSectionLabel(texte, color: teinte),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Icon(
          AppIcons.info,
          size: AppExplainButton.glyphSize,
          color: teinte ?? AppColors.darkTextTertiary,
        ),
      ],
    );
  }
}
