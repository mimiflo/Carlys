import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// En-tête des pages du profil : retour, titre, ligne mono, et une action
/// facultative à droite (le rouage des réglages).
///
/// Le retour vit AU-DESSUS du titre plutôt qu'à sa gauche : la ligne mono
/// est longue (« TON PARCOURS, TA PROGRESSION. ») et ne tiendrait pas entre
/// deux boutons. Il disparaît seul quand il n'y a rien à dépiler.
class ProfilePageHeader extends StatelessWidget {
  const ProfilePageHeader({
    required this.title,
    required this.tagline,
    this.action,
    super.key,
  });

  final String title;

  /// Écrite en capitales à l'affichage.
  final String tagline;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTypography.pageTitle.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tagline.toUpperCase(),
                    style: AppTypography.resized(
                      AppTypography.labelMono,
                      11,
                    ).copyWith(color: AppColors.darkTextSecondary),
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AppSpacing.sm),
              action!,
            ],
          ],
        ),
      ],
    );
  }
}

/// Le rouage des réglages : un disque de surface, cerclé d'un filet.
class ProfileSettingsButton extends StatelessWidget {
  const ProfileSettingsButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.darkBorder)),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: 'Réglages',
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
        ),
        icon: const Icon(
          AppIcons.settingsOutline,
          size: _iconSize,
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}
