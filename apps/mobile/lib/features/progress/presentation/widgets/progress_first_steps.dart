import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import 'add_weight_action.dart';

/// AMORÇAGE : ce qui tient lieu de page tant qu'il n'y a rien à mesurer.
///
/// Le premier jour, l'écran empilait trois états vides (volume, records,
/// poids) et deux tuiles à zéro qui les démentaient : cinq fois la même
/// absence, sans issue. Un seul bloc le dit une fois, et donne les deux
/// gestes qui ouvrent l'écran : une séance, et le poids — dont le calcul de
/// la nutrition a besoin dès le premier jour.
///
/// Sur le modèle de `FirstStepsBody` (profil de progression) et de
/// `TodayPrimer` (accueil) : un état de départ, pas une carte de plus. Il
/// disparaît de lui-même dès qu'une séance, un record ou une mesure existe.
class ProgressFirstSteps extends ConsumerWidget {
  const ProgressFirstSteps({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      container: true,
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
            const AppSectionLabel('Premier jour'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Rien à mesurer pour l’instant',
              style: AppTypography.subheading
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Ta première séance terminée ouvre le volume, les tuiles de la '
              'période et tes records. Ton poids, lui, se note dès '
              'maintenant : le calcul de ta nutrition en a besoin.',
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Lancer une séance',
              icon: AppIcons.arrowForward,
              isExpanded: true,
              onPressed: () => context.push(AppRoutes.templates),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Ajouter mon poids',
              icon: AppIcons.bodyMetrics,
              variant: AppButtonVariant.secondary,
              isExpanded: true,
              onPressed: () => addBodyWeight(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
