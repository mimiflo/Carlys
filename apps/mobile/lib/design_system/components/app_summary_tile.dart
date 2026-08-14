import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Tuile de résumé : pastille d'icône teintée, label mono, valeur, et une
/// précision facultative en dessous.
///
/// Conçue pour la grille 2×2 du « résumé du jour ». Elle n'affiche **jamais**
/// de jauge : ce sont des faits, pas des taux — une jauge supposerait un
/// consommé face à un objectif, ce que le domaine ne fournit pas partout.
class AppSummaryTile extends StatelessWidget {
  const AppSummaryTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.detail,
    super.key,
  });

  final IconData icon;

  /// Teinte de l'icône ; le fond de la pastille en dérive.
  final Color iconColor;

  /// Label court en MAJUSCULES mono (ex. « NUTRITION »).
  final String label;

  /// Valeur mise en avant (ex. « 2 100 kcal », « Push force »).
  final String value;

  /// Précision sous la valeur (ex. « objectif du jour »).
  final String? detail;

  /// Géométrie : pastille ronde de 30 à icône 16.
  static const double _chipSize = 30;
  static const double _iconSize = 16;

  /// Opacité du fond de pastille, dérivée de la teinte de l'icône.
  static const double _chipFill = 0.14;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : $value${detail == null ? '' : ', $detail'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: const BoxDecoration(
            // Surface SECONDAIRE : la tuile vit dans une carte, elle doit
            // s'en détacher. Sur la même surface, elle disparaîtrait.
            color: AppColors.darkSurfaceAlt,
            borderRadius: AppRadius.statTileAll,
            border:
                Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: _chipSize,
                    height: _chipSize,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: _chipFill),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: _iconSize, color: iconColor),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMono.copyWith(
                        fontSize: 10,
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body.copyWith(
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
