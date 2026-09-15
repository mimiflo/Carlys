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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: AppExplainable(
            enonce: 'Dépense totale $total kilocalories',
            onExplain: () => showExplanation(
              context,
              NutritionExplanations.depenseEnergetique,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  total,
                  style: AppTypography.metricXL.copyWith(
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const _LabelExplique('Kcal / dépense totale'),
              ],
            ),
          ),
        ),
        AppExplainable(
          enonce:
              'Métabolisme de base $bmr kilocalories, '
              'dont $activity d’activité',
          // Deux lignes de label ne font pas 48 points : c'est ce
          // rembourrage qui porte le bloc au-dessus de la cible tactile.
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          onExplain: () =>
              showExplanation(context, NutritionExplanations.metabolismeDeBase),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
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
      ],
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
        if (teinte == null)
          AppSectionLabel(texte)
        else
          AppSectionLabel(texte, color: teinte),
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
