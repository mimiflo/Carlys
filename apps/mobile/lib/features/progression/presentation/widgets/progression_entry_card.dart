import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/progression_controllers.dart';

/// Rappel compact du profil de progression : le titre atteint, les points,
/// et la porte vers le détail.
///
/// Adossée aux faits LOCAUX : elle s'affiche donc même quand les
/// statistiques du serveur, autour d'elle, sont hors ligne ou en erreur.
class ProgressionEntryCard extends ConsumerWidget {
  const ProgressionEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(progressionProfileProvider);
    if (profile == null) {
      // L'historique local n'est pas encore lu. Une carte vide vaut mieux
      // qu'un titre provisoire qui changerait sous les yeux.
      return const SizedBox.shrink();
    }

    return AppCard(
      onTap: () => context.push(AppRoutes.progression),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionLabel('Ton titre'),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  profile.title.label,
                  style: AppTypography.title
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${profile.points} points sur les cinq axes.',
                  style: AppTypography.label
                      .copyWith(color: AppColors.darkTextSecondary),
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
