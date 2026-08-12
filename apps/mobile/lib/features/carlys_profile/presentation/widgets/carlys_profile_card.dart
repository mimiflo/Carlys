import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/carlys_profile.dart';
import 'carlys_profile_content.dart';

/// Carte d'un profil, fidèle à la maquette : illustration à gauche, titre en
/// capitales, description courte, chevron cerclé. Le profil ACTUEL porte un
/// badge et un liseré accent — c'est un état, pas un classement.
class CarlysProfileCard extends StatelessWidget {
  const CarlysProfileCard({
    required this.profile,
    required this.isCurrent,
    required this.onTap,
    super.key,
  });

  final CarlysProfile profile;
  final bool isCurrent;
  final VoidCallback onTap;

  static const double _imageWidth = 116;
  static const double _height = 132;

  @override
  Widget build(BuildContext context) {
    final content = carlysProfileContentOf(profile);

    return Semantics(
      button: true,
      label: '${content.title}${isCurrent ? ' — ton profil actuel' : ''}',
      child: Material(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardSecondaryAll,
          child: Ink(
            height: _height,
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardSecondaryAll,
              border: Border.fromBorderSide(
                BorderSide(
                  color: isCurrent ? AppColors.accent : AppColors.darkBorder,
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.lg),
                  ),
                  child: SizedBox(
                    width: _imageWidth,
                    height: double.infinity,
                    child: Image.asset(
                      content.assetPath,
                      fit: BoxFit.cover,
                      // L'illustration n'est pas (encore) embarquée : repli
                      // de marque, jamais un trou ni une icône d'erreur.
                      errorBuilder: (_, __, ___) =>
                          _Placeholder(icon: content.icon),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCurrent) ...[
                        const AppBadge(
                          label: 'Ton profil',
                          variant: AppBadgeVariant.accent,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                      ],
                      Text(
                        content.title.toUpperCase(),
                        style: AppTypography.subheading,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        content.tagline,
                        style: AppTypography.label.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: AppColors.primaryLightBorder),
                      ),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Repli d'illustration : dégradé de marque + icône du profil.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.neutral950],
        ),
      ),
      child: Icon(icon, size: 40, color: AppColors.primaryLight),
    );
  }
}
