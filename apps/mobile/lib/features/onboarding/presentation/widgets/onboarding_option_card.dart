import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Carte de réponse sélectionnable (2i) : gradient primary quand choisie.
class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.fast),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? null : AppColors.darkSurface,
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryCardStrong,
                      AppColors.primaryCardSoft,
                    ],
                  )
                : null,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.all(
              color: selected ? AppColors.primaryLight : AppColors.darkBorder,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? AppColors.primaryLight
                      : AppColors.darkTextTertiary,
                ),
                const SizedBox(width: AppSpacing.gapRow),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.subheading
                          .copyWith(color: AppColors.darkTextPrimary),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        style: AppTypography.body
                            .copyWith(color: AppColors.darkTextSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.primaryLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
