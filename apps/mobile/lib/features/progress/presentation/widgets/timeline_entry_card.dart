import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';

/// L'entrée de la FRISE, depuis l'écran Progrès.
///
/// L'écran Progrès répond à « où j'en suis » ; la frise répond à « d'où je
/// viens ». Deux questions voisines, et c'est pour ça que la porte est ici —
/// mais deux écrans, parce qu'une période et une histoire ne se lisent pas
/// dans la même liste.
class TimelineEntryCard extends StatelessWidget {
  const TimelineEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ton histoire, la frise de tout ce qui s’est passé',
      excludeSemantics: true,
      child: AppCard(
        onTap: () => context.push(AppRoutes.timeline),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xl,
              height: AppSpacing.xl,
              decoration: const BoxDecoration(
                gradient: AppColors.violetRamp,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.history,
                size: 18,
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ton histoire',
                    style: AppTypography.subheading.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Séances, records, pesées et franchissements, dans '
                    'l’ordre où ça s’est passé.',
                    style: AppTypography.label.copyWith(
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              AppIcons.chevronRight,
              size: 20,
              color: AppColors.darkTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
