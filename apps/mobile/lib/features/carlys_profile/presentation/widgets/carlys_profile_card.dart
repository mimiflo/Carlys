import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/carlys_profile.dart';
import 'carlys_profile_content.dart';
import 'profile_medallion.dart';

/// Carte d'un profil (maquette d'octobre 2026) : le médaillon, le nom, la
/// description, puis le chevron — ou, sur le profil retenu, la coche et une
/// pastille au-dessus du nom (« Ton profil » dans les réglages,
/// « Sélectionné » à l'onboarding). La carte retenue prend le liseré violet plein et un fond
/// teinté : c'est un état, pas un classement.
class CarlysProfileCard extends StatelessWidget {
  const CarlysProfileCard({
    required this.profile,
    required this.isCurrent,
    required this.onTap,
    this.selectedLabel = 'Ton profil',
    super.key,
  });

  final CarlysProfile profile;
  final bool isCurrent;
  final VoidCallback onTap;

  /// Ce que dit la carte retenue.
  final String selectedLabel;

  @override
  Widget build(BuildContext context) {
    final content = carlysProfileContentOf(profile);

    // Un seul nœud pour le lecteur d'écran : le nom ET la description, l'état
    // retenu par `selected`, et le geste — `excludeSemantics` retirerait
    // sinon celui de l'InkWell, et la carte ne s'activerait plus.
    return Semantics(
      button: true,
      selected: isCurrent,
      label: '${content.title}. ${content.tagline}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardSecondaryAll,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardSecondaryAll,
              color: isCurrent ? AppColors.primaryBadgeBg : null,
              border: Border.all(
                color: isCurrent
                    ? AppColors.primaryLight
                    : AppColors.primaryLightBorder,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  ProfileMedallion(content: content),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _Texts(
                      content: content,
                      selectedLabel: isCurrent ? selectedLabel : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (isCurrent)
                    const _Coche()
                  else
                    const Icon(
                      AppIcons.chevronRight,
                      size: 24,
                      color: AppColors.primaryLight,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La pastille du profil retenu, le nom et la description, entiers : la
/// carte grandit avec eux. La pastille se resserre plutôt que de déborder
/// d'une colonne étroite (320 points, texte agrandi).
class _Texts extends StatelessWidget {
  const _Texts({required this.content, required this.selectedLabel});

  final CarlysProfileContent content;

  /// `null` sur une carte non retenue.
  final String? selectedLabel;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = this.selectedLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedLabel != null) ...[
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: AppRadius.fullAll,
              ),
              child: Text(
                selectedLabel,
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral950,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        AppWholeWordsText(
          content.title,
          style: AppTypography.heading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        AppWholeWordsText(
          content.tagline,
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// La coche du profil retenu, à la place du chevron.
class _Coche extends StatelessWidget {
  const _Coche();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
      ),
      child: const Icon(AppIcons.check, size: 18, color: AppColors.neutral0),
    );
  }
}
