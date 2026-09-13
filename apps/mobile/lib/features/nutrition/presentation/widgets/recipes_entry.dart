import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';

/// La porte des recettes, depuis l'onglet Nutrition.
///
/// Elle s'affiche que le profil métabolique soit complet ou non : on a le
/// droit de chercher quoi manger avant d'avoir renseigné sa taille. L'écran
/// derrière s'adapte à ce qu'il sait, et se tait sur le reste.
class RecipesEntry extends StatelessWidget {
  const RecipesEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(AppRoutes.recipes),
      child: Row(
        children: [
          const Icon(AppIcons.nutrition, color: AppColors.primaryLight),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recettes',
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                Text(
                  'Petit-déj, collations et repas, classés pour ton objectif.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }
}
