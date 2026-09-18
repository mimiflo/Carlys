import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Carte de CHOIX : un titre, ce que le choix change, l'état « choisi »
/// (fond teinté, bordure claire, coche) — et, au besoin, une image en
/// pastille et un pied libre (une citation, un exemple).
///
/// Née de TROIS copies identiques (voix du Mentor, objectif
/// d'entraînement, expérience) : la grammaire vit ici UNE fois, les
/// feuilles ne portent plus que leur contenu.
class AppChoiceCard extends StatelessWidget {
  const AppChoiceCard({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.selectedSemantics,
    this.description,
    this.icon,
    this.footer,
    super.key,
  });

  final String title;

  /// Ce que le choix change, dit à la personne qui choisit.
  final String? description;

  /// Image du choix, posée en pastille teintée devant le titre.
  final IconData? icon;

  /// Contenu libre sous la description (ex. « Il dira : … »).
  final Widget? footer;

  final bool selected;
  final VoidCallback onTap;

  /// Phrase ajoutée au lecteur d'écran quand la carte est choisie
  /// (« Voix actuelle. », « Objectif actuel. »…) : chaque feuille nomme
  /// SON état, la carte ne devine rien.
  final String selectedSemantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      // `excludeSemantics` retire aussi l'action du InkWell : le relais est
      // obligatoire, sinon la carte est inactivable au lecteur d'écran.
      onTap: onTap,
      label:
          '$title.'
          '${description == null ? '' : ' $description'}'
          '${selected ? ' $selectedSemantics' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryCardSoft
                : AppColors.darkSurfaceAlt,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(
                color: selected ? AppColors.primaryLight : AppColors.darkBorder,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBadgeBg,
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      AppIcons.checkCircle,
                      size: 18,
                      color: AppColors.primaryLight,
                    ),
                  ],
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description!,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.xs),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
