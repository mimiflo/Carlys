import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../typography/app_typography.dart';

/// Ton du texte d'accompagnement d'un en-tête de section.
enum AppSectionTrailingTone { tertiary, primary, accent }

/// En-tête de section de la refonte : titre Inter 15/600 à gauche, valeur ou
/// action en mono 11 à droite (« Records personnels » / « TOUT VOIR »).
///
/// Alignement sur la ligne de base : le titre et la valeur partagent leur
/// assise, comme dans la maquette.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.trailing,
    this.trailingIcon,
    this.trailingTone = AppSectionTrailingTone.tertiary,
    this.onTrailingTap,
    super.key,
  });

  final String title;

  /// Texte de droite, rendu en mono MAJUSCULES.
  final String? trailing;

  /// Icône optionnelle devant le texte de droite (ex. « + AJOUTER »).
  final IconData? trailingIcon;
  final AppSectionTrailingTone trailingTone;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final trailingColor = switch (trailingTone) {
      AppSectionTrailingTone.tertiary => AppColors.darkTextTertiary,
      AppSectionTrailingTone.primary => AppColors.primaryLight,
      AppSectionTrailingTone.accent => AppColors.accent,
    };

    Widget? trailingWidget;
    if (trailing != null) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingIcon != null) ...[
            Icon(trailingIcon, size: 15, color: trailingColor),
            const SizedBox(width: 4),
          ],
          Text(
            trailing!.toUpperCase(),
            style: AppTypography.labelMono.copyWith(
              fontSize: 11,
              color: trailingColor,
            ),
          ),
        ],
      );
      if (onTrailingTap != null) {
        trailingWidget = Semantics(
          button: true,
          child: GestureDetector(
            onTap: onTrailingTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: trailingWidget,
            ),
          ),
        );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.subheading.copyWith(
              fontSize: 15,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        if (trailingWidget != null) trailingWidget,
      ],
    );
  }
}
