import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// AMORÇAGE : ce qui remplace la grille du jour tant qu'aucune cible n'existe.
///
/// Sans profil métabolique, calories, protéines et hydratation n'ont pas de
/// cible — et quatre cellules à « — » ne hiérarchisent rien : elles montrent
/// quatre fois la même absence, sans jamais dire comment en sortir. Une
/// invitation unique le dit une fois, et bien.
///
/// Le bloc disparaît de lui-même dès que le profil est rempli : c'est un état
/// de départ, pas une carte de plus.
class TodayPrimer extends StatelessWidget {
  const TodayPrimer({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: 'Calculer mes objectifs du jour',
      onTap: onStart,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.padCard),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(AppRadius.listRow),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    AppIcons.nutrition,
                    size: 14,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: AppSpacing.xs - 1),
                  Text(
                    'AUJOURD’HUI',
                    style: AppTypography.labelMono.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Carlys ne sait pas encore quoi viser',
                style: AppTypography.subheading
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Ta taille, ton âge, ton objectif : trois minutes, et les '
                'calories, protéines et eau du jour apparaissent ici.',
                style: AppTypography.body
                    .copyWith(color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Calculer mes objectifs',
                  icon: AppIcons.arrowForward,
                  onPressed: onStart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
