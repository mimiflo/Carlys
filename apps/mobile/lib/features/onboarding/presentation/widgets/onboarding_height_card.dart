import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Carte « Taille » : même habillage que les cartes de réponse, mais la
/// valeur se règle au pas à pas plutôt que par sélection.
class OnboardingHeightCard extends StatelessWidget {
  const OnboardingHeightCard({
    required this.heightCm,
    required this.touched,
    required this.onChanged,
    super.key,
  });

  final double heightCm;

  /// Tant que la valeur n'a pas été touchée, la carte reste neutre.
  final bool touched;
  final ValueChanged<double> onChanged;

  static const double minHeightCm = 80;
  static const double maxHeightCm = 250;

  /// Géométrie de la maquette : icône 24. Les flèches de réglage, elles,
  /// vivent dans la boîte tactile du design system : à 28 points, elles
  /// tenaient tout juste au-dessus du plancher WCAG.
  static const double _iconSize = 24;
  static const double _selectedBorderWidth = 1.5;

  void _shift(double delta) {
    final next = (heightCm + delta).clamp(minHeightCm, maxHeightCm);
    if (next != heightCm) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.resolve(context, AppMotion.fast),
      curve: AppMotion.standard,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: touched ? AppColors.accentBadgeBg : AppColors.darkSurface,
        borderRadius: AppRadius.listRowAll,
        border: Border.all(
          color: touched ? AppColors.accent : AppColors.darkBorder,
          width: touched ? _selectedBorderWidth : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.units,
            size: _iconSize,
            color: touched ? AppColors.accent : AppColors.primaryLight,
          ),
          const SizedBox(width: AppSpacing.gapRow),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Taille',
                  style: AppTypography.subheading
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Utilisée pour l’IMC',
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
          _StepButton(
            icon: AppIcons.minus,
            label: 'Diminuer la taille',
            onTap: () => _shift(-1),
          ),
          Semantics(
            label: 'Taille : ${formatThousands(heightCm)} centimètres',
            child: Text(
              '${formatThousands(heightCm)} cm',
              style: AppTypography.metricS.copyWith(
                color: touched ? AppColors.accent : AppColors.darkTextPrimary,
              ),
            ),
          ),
          _StepButton(
            icon: AppIcons.add,
            label: 'Augmenter la taille',
            onTap: () => _shift(1),
          ),
        ],
      ),
    );
  }
}

/// Flèche de réglage : un glyphe de 16 au centre de la boîte tactile.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppSpacing.touchTarget,
          child: Center(
            child: Icon(
              icon,
              size: AppSpacing.md,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
