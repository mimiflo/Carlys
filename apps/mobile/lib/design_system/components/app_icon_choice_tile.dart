import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Une tuile de CHOIX EXCLUSIF : une icône au-dessus d'un libellé court.
///
/// Née pour le moment d'un repas (petit-déjeuner, déjeuner, dîner,
/// collation) : quatre tuiles égales, dont une seule est choisie — fond
/// violet, filet violet clair, libellé en texte principal. Les autres
/// restent sur la surface alternée, en texte secondaire.
///
/// C'est un cousin compact d'`AppChoiceCard`, qui porte un titre ET ce que
/// le choix change : ici le libellé suffit, et quatre cartes ne tiendraient
/// pas sur une rangée. À poser dans une `AppAdaptiveGrid`, qui passe à deux
/// colonnes quand le texte est agrandi.
///
/// La tuile entière répond au doigt, et fait au moins la cible tactile.
class AppIconChoiceTile extends StatelessWidget {
  const AppIconChoiceTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final ink = selected
        ? AppColors.darkTextPrimary
        : AppColors.darkTextSecondary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? AppColors.primaryCardStrong
            : AppColors.darkSurfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: selected ? AppColors.primaryLight : AppColors.darkBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Le voile violet des badges, au lieu du gris clair du thème : sous
          // le doigt, le gris éclaircissait la tuile jusqu'à éteindre son
          // libellé (2,05:1 à l'appui, mesuré par `contrast_pairs_test`).
          overlayColor: const WidgetStatePropertyAll(AppColors.primaryBadgeBg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: _iconSize,
                    color: selected ? AppColors.primaryLight : ink,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(
                      color: ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
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
