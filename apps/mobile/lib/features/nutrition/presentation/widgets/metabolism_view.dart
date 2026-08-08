import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import 'macros_card.dart';

/// Résultats métaboliques (maquette 2g) : macros en jauges, puis les données
/// corporelles réellement fournies par le serveur (IMC, hydratation).
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
        AppSectionHeader(title: 'Macros', trailing: 'Objectif $target kcal'),
        const SizedBox(height: AppSpacing.sm),
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
              ),
            ),
            const SizedBox(width: AppSpacing.gapTile),
            Expanded(
              child: AppStatTile(
                label: 'Eau',
                value: waterLitres,
                unit: ' L',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
