import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';

/// Training — tout l'entraînement derrière une seule porte.
///
/// Le hub ne refait aucun écran : il ORCHESTRE ceux qui existent — séances,
/// exercices, coach, historique. Une seule exception : la séance en cours,
/// qui a droit à sa carte d'appel quand elle existe, parce qu'y retourner
/// est l'action la plus probable de l'onglet.
class TrainingHubScreen extends ConsumerWidget {
  const TrainingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          MediaQuery.paddingOf(context).top + AppSpacing.gapSection,
          AppSpacing.gutter,
          bottomInset + AppSpacing.gapSection,
        ),
        children: [
          Text(
            'Training',
            style: AppTypography.display
                .copyWith(color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Séances, exercices, coach — tout l’entraînement.',
            style:
                AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
          ),
          const SizedBox(height: AppSpacing.gapRow),
          if (active != null) ...[
            AppCard(
              onTap: () => context.push(AppRoutes.activeWorkout),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.accent,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Séance en cours',
                          style: AppTypography.subheading
                              .copyWith(color: AppColors.darkTextPrimary),
                        ),
                        Text(
                          'Reprendre là où tu t’es arrêté.',
                          style: AppTypography.body
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
            ),
            const SizedBox(height: AppSpacing.gapRow),
          ],
          _Entry(
            icon: Icons.event_note_outlined,
            color: AppColors.accent,
            title: 'Mes séances',
            subtitle: 'Modèles prêts à lancer, checklist d’exercices.',
            onTap: () => context.push(AppRoutes.templates),
          ),
          _Entry(
            icon: AppIcons.workout,
            color: AppColors.primaryLight,
            title: 'Exercices',
            subtitle: 'Le catalogue complet, par groupe musculaire.',
            onTap: () => context.push(AppRoutes.exercises),
          ),
          _Entry(
            icon: AppIcons.coach,
            color: AppColors.primaryLight,
            title: 'Coach IA',
            subtitle: 'Questions, explications, séances adaptées.',
            onTap: () => context.push(AppRoutes.coach),
          ),
          _Entry(
            icon: Icons.calendar_month_outlined,
            color: AppColors.accent,
            title: 'Calendrier & historique',
            subtitle: 'Tes séances passées, mois par mois.',
            onTap: () => context.push(AppRoutes.history),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gapRow),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.subheading
                        .copyWith(color: AppColors.darkTextPrimary),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.body
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
      ),
    );
  }
}
