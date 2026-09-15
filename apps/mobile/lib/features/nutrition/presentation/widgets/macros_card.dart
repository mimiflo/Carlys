import 'package:flutter/material.dart';

import '../../../../core/explanations/explanation.dart';
import '../../../../core/explanations/explanation_sheet.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/nutrition_explanations.dart';

/// Carte macros (maquette 2g) : trois lignes « nom → grammes » surmontant
/// chacune une jauge de 6.
///
/// L'app ne suit AUCUN apport alimentaire : les jauges expriment donc la part
/// de l'objectif calorique couverte par chaque macro (grammes × kcal/g ÷
/// objectif), et non une consommation du jour.
///
/// Chaque ligne ouvre son POURQUOI. Les trois répartitions n'ont rien
/// d'évident — la part de protéines est la plus HAUTE en perte de gras, les
/// glucides ne sont qu'un solde — et un chiffre sans sa raison ne s'ajuste
/// pas, il se subit.
class MacrosCard extends StatelessWidget {
  const MacrosCard({required this.metabolism, super.key});

  final MetabolismResult metabolism;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Le rembourrage vertical descend dans chaque ligne : c'est elle qui
      // porte la cible tactile, et son onde doit filer jusqu'aux bords.
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MacroRow(
            label: 'Protéines',
            grams: metabolism.proteinG,
            kcalPerGram: 4,
            targetKcal: metabolism.targetKcal,
            color: AppColors.accent,
            explication: NutritionExplanations.proteines,
          ),
          MacroRow(
            label: 'Glucides',
            grams: metabolism.carbsG,
            kcalPerGram: 4,
            targetKcal: metabolism.targetKcal,
            color: AppColors.primary,
            explication: NutritionExplanations.glucides,
          ),
          MacroRow(
            label: 'Lipides',
            grams: metabolism.fatG,
            kcalPerGram: 9,
            targetKcal: metabolism.targetKcal,
            color: AppColors.primaryLight,
            explication: NutritionExplanations.lipides,
          ),
        ],
      ),
    );
  }
}

/// Une ligne de macro : libellé, grammes en mono, jauge de répartition.
///
/// Avec une [explication], la ligne ENTIÈRE devient la cible tactile et porte
/// le glyphe d'information derrière son libellé. Un bouton de 48 posé en bout
/// de ligne aurait fait grandir la carte de moitié pour une zone plus petite
/// que la ligne elle-même.
class MacroRow extends StatelessWidget {
  const MacroRow({
    required this.label,
    required this.grams,
    required this.kcalPerGram,
    required this.targetKcal,
    required this.color,
    this.explication,
    super.key,
  });

  final String label;
  final int grams;
  final int kcalPerGram;
  final int targetKcal;
  final Color color;
  final Explanation? explication;

  /// Grammes en mono tabulaire, à la taille du label texte (12).
  ///
  /// `!` justifié : `AppTypography.label` est une constante du design system
  /// qui pose toujours `fontSize` ; c'est `TextStyle` qui le déclare
  /// facultatif, pas nous. L'interlettrage est remis à ZÉRO exprès — les
  /// chiffres sont déjà tabulaires, les espacer les désalignerait de la
  /// colonne voisine.
  static final TextStyle _valueStyle = AppTypography.resized(
    AppTypography.labelMono,
    AppTypography.label.fontSize!,
  ).copyWith(letterSpacing: 0, color: AppColors.darkTextSecondary);

  @override
  Widget build(BuildContext context) {
    final share = targetKcal <= 0
        ? 0.0
        : (grams * kcalPerGram / targetKcal).clamp(0.0, 1.0);
    final value = '${formatThousands(grams)} g';
    final explication = this.explication;

    // Le contenu ne fait qu'une trentaine de points : c'est ce rembourrage
    // qui porte la ligne au-dessus de la cible tactile minimale.
    const marge = EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.gapTile,
    );

    final corps = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
            if (explication != null) ...[
              const SizedBox(width: AppSpacing.xxs),
              const Icon(
                AppIcons.info,
                size: AppExplainButton.glyphSize,
                color: AppColors.darkTextTertiary,
              ),
            ],
            const Spacer(),
            Text(value, style: _valueStyle),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AppGauge(progress: share, color: color),
      ],
    );

    final enonce = '$label : $value par jour';

    if (explication == null) {
      return Semantics(
        label: enonce,
        excludeSemantics: true,
        child: Padding(padding: marge, child: corps),
      );
    }

    return AppExplainable(
      enonce: enonce,
      padding: marge,
      onExplain: () => showExplanation(context, explication),
      child: corps,
    );
  }
}
