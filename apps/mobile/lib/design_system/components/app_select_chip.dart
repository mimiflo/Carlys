import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Une pastille de CHOIX d'en-tête : une icône, la valeur courante et un
/// chevron — « Aujourd'hui » du journal, « Mois » des progrès. La
/// toucher ouvre ce qui change la valeur (calendrier, feuille de périodes).
class AppSelectChip extends StatelessWidget {
  const AppSelectChip({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    super.key,
  });

  final String label;

  /// Ce que le lecteur d'écran annonce : la valeur ET ce que fait l'appui.
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      // Le nœud remplace ceux de l'InkWell : il porte donc le geste.
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.darkSurfaceAlt,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.darkBorder),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          // Bornée par l'écran : posée dans une rangée qui ne la borne pas
          // (les actions d'en-tête), la pastille coupe son libellé en grand
          // texte plutôt que de déborder.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: AppSpacing.touchTarget,
              maxWidth: MediaQuery.sizeOf(context).width - 2 * AppSpacing.md,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.calendar, color: AppColors.primaryLight),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  const Icon(AppIcons.choose, color: AppColors.primaryLight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
