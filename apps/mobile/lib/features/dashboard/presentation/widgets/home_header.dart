import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// En-tête de l'accueil : date du jour en mono, salutation en display,
/// avatar 44×44 en dégradé violet portant l'initiale.
class HomeHeader extends StatelessWidget {
  const HomeHeader({required this.displayName, super.key});

  final String? displayName;

  /// Géométrie de la maquette : vignette carrée de 44.
  static const double _avatarSize = 44;

  @override
  Widget build(BuildContext context) {
    final firstName = displayName?.split(' ').first;
    final initial = firstName == null || firstName.isEmpty
        ? '?'
        : firstName.characters.first.toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionLabel(formatLongDateMono(DateTime.now())),
              const SizedBox(height: AppSpacing.xs),
              Text(
                firstName == null ? 'Bonjour' : 'Bonjour,\n$firstName',
                style: AppTypography.display
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
            ],
          ),
        ),
        Semantics(
          label: firstName == null ? 'Profil' : 'Profil de $firstName',
          child: Container(
            width: _avatarSize,
            height: _avatarSize,
            decoration: BoxDecoration(
              borderRadius: AppRadius.avatarAll,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  // Violet éteint de la maquette, dérivé des tokens.
                  Color.lerp(
                    AppColors.primary,
                    AppColors.darkBackground,
                    0.55,
                  )!,
                ],
              ),
              border: const Border.fromBorderSide(
                BorderSide(color: AppColors.darkBorderStrong),
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: AppTypography.subheading.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
