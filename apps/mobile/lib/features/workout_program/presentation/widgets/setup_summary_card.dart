import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Une réponse déjà donnée, en une carte : une icône ronde teintée, son nom,
/// ce qu'elle veut dire, et un chevron qui rouvre le choix (« Avancé / Plus
/// de trois ans… »). L'écran se lit d'un coup d'œil ; le détail des options
/// ne s'ouvre que pour en changer.
class SetupSummaryCard extends StatelessWidget {
  const SetupSummaryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  /// Ce que le lecteur d'écran dit à la place de la carte : la valeur
  /// d'abord, puis le geste (« Ton objectif : Hyrox. Modifier »).
  final String semanticLabel;
  final VoidCallback onTap;

  static const double _iconSize = 22;
  static const double _badgeSize = 48;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: semanticLabel,
      // La carte parle par son libellé : lus à la suite, le geste passait
      // avant la valeur, et « Choisir mon objectif » doublait le libellé.
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: _badgeSize,
              height: _badgeSize,
              decoration: const BoxDecoration(
                color: AppColors.primaryBadgeBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: _iconSize, color: AppColors.primaryLight),
            ),
            const SizedBox(width: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description,
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              AppIcons.chevronRight,
              color: AppColors.darkTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
