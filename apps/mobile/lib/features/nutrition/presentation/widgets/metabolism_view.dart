import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';
import 'metabolism_hero.dart';

/// Résultats métaboliques (2b) : macros en jauges, objectif, IMC, eau.
class MetabolismView extends StatelessWidget {
  const MetabolismView({
    required this.profile,
    required this.metabolism,
    super.key,
  });

  final MetabolicProfile profile;
  final MetabolismResult metabolism;

  @override
  Widget build(BuildContext context) {
    final water =
        (metabolism.waterMl / 1000).toStringAsFixed(1).replaceFirst('.', ',');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Macros ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardSecondaryAll,
            border:
                Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Macros',
                      style: AppTypography.heading
                          .copyWith(color: AppColors.darkTextPrimary),
                    ),
                  ),
                  AppSectionLabel(
                    '${MetabolismHero.formatKcal(metabolism.targetKcal)} '
                    'kcal objectif',
                    color: AppColors.darkTextTertiary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _MacroRow(
                label: 'Protéines',
                grams: metabolism.proteinG,
                kcalPerGram: 4,
                targetKcal: metabolism.targetKcal,
                color: AppColors.accent,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MacroRow(
                label: 'Glucides',
                grams: metabolism.carbsG,
                kcalPerGram: 4,
                targetKcal: metabolism.targetKcal,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MacroRow(
                label: 'Lipides',
                grams: metabolism.fatG,
                kcalPerGram: 9,
                targetKcal: metabolism.targetKcal,
                color: AppColors.primaryLight,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Objectif · IMC · Eau ─────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: AppStatTile(
                label: 'Objectif quotidien',
                value: '${metabolism.targetKcal}',
                unit: ' kcal',
              ),
            ),
            const SizedBox(width: AppSpacing.gapTile),
            Expanded(
              child: AppStatTile(label: 'IMC', value: '${metabolism.bmi}'),
            ),
            const SizedBox(width: AppSpacing.gapTile),
            Expanded(
              child: AppStatTile(label: 'Eau', value: water, unit: ' L'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AppPill(
              label: metabolism.bmiCategory.label,
              tone: metabolism.bmiCategory == BmiCategory.normal
                  ? AppPillTone.accent
                  : AppPillTone.primary,
            ),
            if (profile.goal != null) ...[
              const SizedBox(width: AppSpacing.xs),
              AppPill(label: profile.goal!.label),
            ],
          ],
        ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.grams,
    required this.kcalPerGram,
    required this.targetKcal,
    required this.color,
  });

  final String label;
  final int grams;
  final int kcalPerGram;
  final int targetKcal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final share = targetKcal <= 0
        ? 0.0
        : (grams * kcalPerGram / targetKcal).clamp(0.0, 1.0);

    return Semantics(
      label: '$label : $grams grammes par jour',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.body
                    .copyWith(color: AppColors.darkTextSecondary),
              ),
              Text(
                '$grams g',
                style: AppTypography.metricS
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppGauge(progress: share, color: color),
        ],
      ),
    );
  }
}
