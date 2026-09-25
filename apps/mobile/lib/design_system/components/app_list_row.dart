import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../typography/app_typography.dart';

/// Ligne de liste de la refonte : vignette 36 → titre + sous-titre mono
/// MAJUSCULES → valeur mono ou chevron à droite.
class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingTint,
    this.trailing,
    this.trailingText,
    this.onTap,
    super.key,
  });

  final String title;

  /// Sous-titre affiché en labelMono MAJUSCULES tertiaire.
  final String? subtitle;

  /// Icône de la vignette 36×36 (rayon 12, fond teinté).
  final IconData? leading;

  /// Teinte de la vignette (défaut : primaire).
  final Color? leadingTint;

  /// Widget de droite (prioritaire sur [trailingText]).
  final Widget? trailing;

  /// Valeur de droite en `metricS`.
  final String? trailingText;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = leadingTint ?? AppColors.primaryLight;
    // Une ligne, coupée d'une ellipse, à la taille de texte d'origine : la
    // liste garde son rythme. Texte AGRANDI, au contraire, le titre passe à
    // la ligne : sur 320 points à 200 %, « Choisir dans la galerie » ne
    // gardait que ses premières lettres, et c'est le choix même qu'on perdait.
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1;
    final int? lines = enlarged ? null : 1;
    final TextOverflow? cut = enlarged ? null : TextOverflow.ellipsis;

    final content = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.listRowAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: tint.withValues(alpha: 0.28)),
              ),
              child: Icon(leading, size: 18, color: tint),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: lines,
                  overflow: cut,
                  style: AppTypography.resized(
                    AppTypography.subheading,
                    14,
                  ).copyWith(color: AppColors.darkTextPrimary),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!.toUpperCase(),
                    maxLines: lines,
                    overflow: cut,
                    style: AppTypography.labelMono.copyWith(
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          if (trailing != null)
            trailing!
          else if (trailingText != null)
            Text(
              trailingText!,
              style: AppTypography.metricS.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            )
          else if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.darkTextTertiary,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.listRowAll,
        child: content,
      ),
    );
  }
}
