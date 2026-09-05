import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// L'EN-TÊTE DU PROFIL : le nom de l'écran, ce qu'il raconte, et l'avatar.
///
/// Le sous-titre change avec l'état du compte, et c'est volontaire : un
/// compte neuf n'a pas « déposé » quoi que ce soit, lui dire le contraire
/// serait la première fausse note de l'écran.
class ProgressionHeader extends StatelessWidget {
  const ProgressionHeader({
    required this.subtitle,
    required this.initial,
    this.majestic = true,
    super.key,
  });

  /// Ce que l'écran raconte, en une phrase.
  final String subtitle;

  /// L'initiale portée par l'avatar.
  final String initial;

  /// L'avatar prend son dégradé. Un compte neuf ne l'a pas : le dégradé se
  /// gagne, comme le reste de l'écran.
  final bool majestic;

  static const double _avatarSize = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Progression',
                style: AppTypography.display.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs + 2),
              Text(
                subtitle,
                style: AppTypography.body.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _Avatar(initial: initial, majestic: majestic),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.majestic});

  final String initial;
  final bool majestic;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ProgressionHeader._avatarSize,
      height: ProgressionHeader._avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: majestic ? AppColors.avatarMajestic : null,
        color: majestic ? null : AppColors.darkSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.avatar),
        border: Border.all(color: AppColors.darkBorderStrong),
      ),
      child: Text(
        initial,
        style: AppTypography.subheading.copyWith(
          fontWeight: FontWeight.w700,
          color: majestic ? AppColors.neutral0 : AppColors.darkTextSecondary,
        ),
      ),
    );
  }
}
