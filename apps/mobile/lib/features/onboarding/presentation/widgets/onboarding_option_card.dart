import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Carte de réponse de l'onboarding.
///
/// Non sélectionnée : surface sombre + bordure discrète, icône violette.
/// Sélectionnée : fond accent voilé, bordure accent 1,5 et pastille de
/// validation à droite.
class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  /// Contrôle à droite (pas à pas de la taille) — remplace la coche.
  final Widget? trailing;

  /// Géométrie de la maquette : icône 24, coche 22.
  static const double _iconSize = 24;
  static const double _checkSize = 22;
  static const double _selectedBorderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBadgeBg : AppColors.darkSurface,
            borderRadius: AppRadius.listRowAll,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.darkBorder,
              width: selected ? _selectedBorderWidth : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: _iconSize,
                  color: selected ? AppColors.accent : AppColors.primaryLight,
                ),
                const SizedBox(width: AppSpacing.gapRow),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: AppTypography.label.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (selected)
                const Icon(
                  AppIcons.checkCircle,
                  size: _checkSize,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
