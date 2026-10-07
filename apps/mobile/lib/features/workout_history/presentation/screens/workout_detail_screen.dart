import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../domain/services/exercise_breakdown.dart';
import '../widgets/exercise_summary_card.dart';
import '../widgets/workout_conflict_card.dart';
import '../widgets/workout_retry_sync_card.dart';
import '../widgets/workout_summary_hero.dart';
import '../widgets/workout_summary_stats.dart';

/// Le BILAN d'une séance (maquette d'octobre 2026) : l'écran qui suit la
/// clôture, et celui qu'ouvre une séance de l'historique.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(sessionId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: AppScreenHeader.centered(
                title: 'Bilan de séance',
                tagline: 'Chaque effort compte',
              ),
            ),
            Expanded(
              child: detail.when(
                loading: () => const AppLoadingIndicator(label: 'Chargement'),
                // La séance absente a sa propre branche (`data` nul,
                // ci-dessous) : arriver ICI, c'est une vraie panne de lecture
                // locale, le cas même où réessayer a un sens.
                error: (_, __) => AppErrorState(
                  title: 'Séance indisponible',
                  onRetry: () =>
                      ref.invalidate(workoutDetailProvider(sessionId)),
                ),
                data: (workout) => workout == null
                    ? const AppEmptyState(
                        title: 'Séance introuvable',
                        icon: AppIcons.history,
                      )
                    : _SummaryBody(workout: workout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.workout});

  final WorkoutWithSets workout;

  @override
  Widget build(BuildContext context) {
    final session = workout.session;
    final exercises = breakdownByExercise(workout.sets);
    final count = exercises.length;

    return ListView(
      primary: true,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        MediaQuery.paddingOf(context).bottom + AppSpacing.md,
      ),
      children: [
        WorkoutSummaryHero(session: session),
        if (session.syncState != LocalSyncState.synced) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppBadge(
              label: session.syncState.label,
              variant: switch (session.syncState) {
                LocalSyncState.failed ||
                LocalSyncState.conflict => AppBadgeVariant.warning,
                LocalSyncState.pending ||
                LocalSyncState.synced => AppBadgeVariant.neutral,
              },
            ),
          ),
        ],
        // Le serveur a refusé la clôture : le choix est proposé ici, sur la
        // séance elle-même, là où l'utilisateur voit ce qu'il tranche.
        if (session.syncState == LocalSyncState.conflict) ...[
          const SizedBox(height: AppSpacing.md),
          WorkoutConflictCard(session: session),
        ],
        // Envoi mis de côté après trop d'erreurs serveur : le rejeu
        // automatique n'a lieu qu'à la prochaine ouverture. Le geste est
        // proposé ici, sur la séance concernée.
        if (session.syncState == LocalSyncState.failed) ...[
          const SizedBox(height: AppSpacing.md),
          WorkoutRetrySyncCard(session: session),
        ],
        const SizedBox(height: AppSpacing.md),
        WorkoutSummaryStats(workout: workout),
        const SizedBox(height: AppSpacing.gapSection),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Détail des exercices',
                  style: AppTypography.heading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${formatThousands(count)} exercice${count > 1 ? 's' : ''}',
              style: AppTypography.body.copyWith(color: AppColors.primaryLight),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (exercises.isEmpty)
          const AppEmptyState(
            title: 'Aucune série enregistrée',
            icon: AppIcons.workout,
          ),
        for (final (index, exercise) in exercises.indexed) ...[
          ExerciseSummaryCard(
            key: ValueKey(exercise.id),
            sessionId: session.id,
            exercise: exercise,
            initiallyExpanded: index == 0,
          ),
          const SizedBox(height: AppSpacing.gapTile),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Les séries enregistrées restent consultables dans ton historique.',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCtaButton(
          label: 'Retour à l’entraînement',
          icon: AppIcons.arrowForward,
          onPressed: () => context.go(AppRoutes.training),
        ),
      ],
    );
  }
}
