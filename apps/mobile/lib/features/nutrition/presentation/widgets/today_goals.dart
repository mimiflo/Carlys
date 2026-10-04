import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../domain/services/day_intake.dart';
import '../providers/journal_day_provider.dart';
import '../providers/nutrition_providers.dart';
import 'daily_goals_card.dart';

/// Les objectifs du jour affiché, dans tous leurs états : le calcul du
/// serveur et le journal se lisent ensemble ; un profil incomplet mène à
/// « Mon métabolisme », où il se complète.
class TodayGoals extends ConsumerWidget {
  const TodayGoals({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(metabolismReportProvider);
    final day = ref.watch(journalDayProvider);
    final meals = ref.watch(mealsForDayProvider(day));

    return report.when(
      loading: () => const AppCard(
        child: AppLoadingIndicator(label: 'Calcul de tes objectifs'),
      ),
      error: (error, _) => ConnectionAwareError(
        error: error,
        title: 'Objectifs indisponibles',
        message: 'Tes objectifs n’ont pas pu être calculés. Réessaie.',
        offlineMessage:
            'Tes objectifs se calculent sur le serveur : ils reviennent '
            'avec le réseau.',
        onRetry: () => ref.invalidate(metabolismReportProvider),
      ),
      data: (data) {
        final target = data.metabolism;
        if (target == null) {
          return AppCard(
            onTap: () => context.push(AppRoutes.metabolism),
            semanticLabel: 'Compléter mon profil',
            child: Row(
              children: [
                const Icon(AppIcons.metabolism, color: AppColors.primaryLight),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compléter mon profil',
                        style: AppTypography.subheading.copyWith(
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                      Text(
                        'Taille, âge, activité : tes objectifs du jour se '
                        'calculent dessus.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  AppIcons.chevronRight,
                  color: AppColors.darkTextTertiary,
                ),
              ],
            ),
          );
        }
        // Le journal se charge, ou manque : l'anneau attend plutôt que
        // d'afficher un « 0 mangé » qu'aucun repas ne dit. Son erreur est
        // dite une fois, par le journal plus bas.
        final eaten = meals.valueOrNull;
        if (eaten == null && meals.hasError) {
          return AppCard(
            child: Text(
              'Tes objectifs : ${formatThousands(target.targetKcal)} kcal. Ce que tu as '
              'mangé revient avec le journal.',
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          );
        }
        if (eaten == null) {
          return const AppCard(
            child: AppLoadingIndicator(label: 'Lecture du journal'),
          );
        }
        return DailyGoalsCard(target: target, intake: dayIntake(eaten.meals));
      },
    );
  }
}
