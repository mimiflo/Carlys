import 'package:flutter/material.dart';

import '../../../../core/explanations/explanation_sheet.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/nutrition_explanations.dart';
import 'macros_card.dart';

/// Résultats métaboliques (maquette 2g) : macros en jauges, puis les données
/// corporelles réellement fournies par le serveur (IMC, hydratation).
///
/// Chaque chiffre porte sa porte d'explication. C'est la promesse de marque
/// appliquée : « Carlys ne dit jamais seulement quoi faire, il explique
/// toujours pourquoi ». L'écran annonçait « IMC 27,3 » et « Surpoids » sans un
/// mot — un verdict, pas une explication.
class MetabolismView extends StatelessWidget {
  const MetabolismView({required this.metabolism, super.key});

  final MetabolismResult metabolism;

  @override
  Widget build(BuildContext context) {
    // L'app ne suit pas les apports : l'en-tête n'annonce que l'objectif
    // calculé par le serveur, jamais un « consommé / objectif ».
    final target = formatThousands(metabolism.targetKcal);
    final waterLitres = formatDecimal(metabolism.waterMl / 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Macros',
          trailing: 'Objectif $target kcal',
          trailingIcon: AppIcons.info,
          onTrailingTap: () =>
              showExplanation(context, NutritionExplanations.caloriesCibles),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Une cible relevée au plancher ne vaut plus « dépense × objectif » :
        // l'afficher nue la ferait contredire sa propre explication, celle
        // que le bouton d'en-tête vient d'ouvrir. On le dit donc à côté du
        // chiffre, avec sa porte, plutôt que de laisser deviner.
        if (metabolism.targetKcalFloored) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: AppPill(
              label: 'Cible relevée au minimum de sécurité',
              tone: AppPillTone.accent,
              icon: AppIcons.info,
              onTap: () => showExplanation(
                context,
                NutritionExplanations.plancherCalorique,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        MacrosCard(metabolism: metabolism),
        const SizedBox(height: AppSpacing.gapSection),
        AppSectionHeader(
          title: 'Corps',
          trailing: metabolism.bmiCategory.label,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'IMC',
                value: formatDecimal(metabolism.bmi),
                onExplain: () =>
                    showExplanation(context, NutritionExplanations.imc),
              ),
            ),
            const SizedBox(width: AppSpacing.gapTile),
            Expanded(
              child: AppStatTile(
                label: 'Eau',
                value: waterLitres,
                unit: ' L',
                onExplain: () =>
                    showExplanation(context, NutritionExplanations.eau),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // La donnée qu'on N'AFFICHE PAS mérite son explication autant que les
        // autres : c'est la question que tout le monde se pose en voyant un
        // IMC, et y répondre par « nous ne le mesurons pas, voici pourquoi »
        // vaut mieux que par une estimation qui se trompe.
        Align(
          alignment: Alignment.centerLeft,
          child: AppPill(
            label: 'Et ma masse grasse ?',
            icon: AppIcons.info,
            onTap: () => showExplanation(
              context,
              NutritionExplanations.masseGrasseEtMusculaire,
            ),
          ),
        ),
      ],
    );
  }
}
