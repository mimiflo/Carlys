import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';

/// Carte macros (maquette 2g) : trois lignes « nom → grammes » surmontant
/// chacune une jauge de 6.
///
/// L'app ne suit AUCUN apport alimentaire : les jauges expriment donc la part
/// de l'objectif calorique couverte par chaque macro (grammes × kcal/g ÷
/// objectif), et non une consommation du jour.
class MacrosCard extends StatelessWidget {
  const MacrosCard({required this.metabolism, super.key});

  final MetabolismResult metabolism;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          ),
          const SizedBox(height: AppSpacing.sm),
          MacroRow(
            label: 'Glucides',
            grams: metabolism.carbsG,
            kcalPerGram: 4,
            targetKcal: metabolism.targetKcal,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          MacroRow(
            label: 'Lipides',
            grams: metabolism.fatG,
            kcalPerGram: 9,
            targetKcal: metabolism.targetKcal,
            color: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }
}

/// Une ligne de macro : libellé, grammes en mono, jauge de répartition.
class MacroRow extends StatelessWidget {
  const MacroRow({
    required this.label,
    required this.grams,
    required this.kcalPerGram,
    required this.targetKcal,
    required this.color,
    super.key,
  });

  final String label;
  final int grams;
  final int kcalPerGram;
  final int targetKcal;
  final Color color;

  /// Grammes en mono tabulaire, à la taille du label texte (12).
  static final TextStyle _valueStyle = AppTypography.labelMono.copyWith(
    fontSize: AppTypography.label.fontSize,
    letterSpacing: 0,
    color: AppColors.darkTextSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final share = targetKcal <= 0
        ? 0.0
        : (grams * kcalPerGram / targetKcal).clamp(0.0, 1.0);
    final value = '${formatThousands(grams)} g';

    return Semantics(
      label: '$label : $value par jour',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              Text(value, style: _valueStyle),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AppGauge(progress: share, color: color),
        ],
      ),
    );
  }
}
