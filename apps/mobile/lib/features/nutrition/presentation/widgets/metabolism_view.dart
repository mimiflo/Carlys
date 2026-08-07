import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/nutrition.dart';

/// Résultats métaboliques : objectif calorique, BMR/TDEE, macros, IMC, eau.
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          semanticLabel:
              'Objectif calorique : ${metabolism.targetKcal} kilocalories par jour',
          child: Column(
            children: [
              Text('Objectif quotidien', style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${metabolism.targetKcal} kcal',
                style: AppTypography.metric.copyWith(
                  fontSize: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (profile.goal != null) ...[
                const SizedBox(height: AppSpacing.xs),
                AppBadge(
                  label: profile.goal!.label,
                  variant: AppBadgeVariant.primary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Métabolisme de base',
                value: '${metabolism.bmrKcal} kcal',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricCard(
                label: 'Dépense totale',
                value: '${metabolism.tdeeKcal} kcal',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Macro-nutriments', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _MacroBar(
                label: 'Protéines',
                grams: metabolism.proteinG,
                kcalPerGram: 4,
                targetKcal: metabolism.targetKcal,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MacroBar(
                label: 'Lipides',
                grams: metabolism.fatG,
                kcalPerGram: 9,
                targetKcal: metabolism.targetKcal,
                color: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MacroBar(
                label: 'Glucides',
                grams: metabolism.carbsG,
                kcalPerGram: 4,
                targetKcal: metabolism.targetKcal,
                color: AppColors.accentDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppCard(
                semanticLabel:
                    'IMC : ${metabolism.bmi}, ${metabolism.bmiCategory.label}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${metabolism.bmi}',
                      style: AppTypography.metric.copyWith(
                        fontSize: 24,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('IMC', style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    AppBadge(
                      label: metabolism.bmiCategory.label,
                      variant: metabolism.bmiCategory == BmiCategory.normal
                          ? AppBadgeVariant.accent
                          : AppBadgeVariant.warning,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricCard(
                label: 'Hydratation conseillée',
                value:
                    '${(metabolism.waterMl / 1000).toStringAsFixed(1).replaceFirst('.', ',')} L',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      semanticLabel: '$label : $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.metric.copyWith(
              fontSize: 24,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
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
    final theme = Theme.of(context);
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
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                '$grams g',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          ClipRRect(
            borderRadius: AppRadius.xsAll,
            child: LinearProgressIndicator(
              value: share,
              minHeight: AppSpacing.xs,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
