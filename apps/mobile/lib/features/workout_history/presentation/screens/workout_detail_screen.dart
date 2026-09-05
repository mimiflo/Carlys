import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';

/// Détail (et résumé de fin) d'une séance.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Séance')),
      body: SafeArea(
        child: detail.when(
          loading: () => const AppLoadingIndicator(label: 'Chargement'),
          error: (_, __) => const AppErrorState(title: 'Séance indisponible'),
          data: (workout) => workout == null
              ? const AppEmptyState(
                  title: 'Séance introuvable',
                  icon: AppIcons.history,
                )
              : _DetailBody(workout: workout),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.workout});

  final WorkoutWithSets workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = workout.session;
    final templateName = session.templateName;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Provenance de la séance : dénormalisée au lancement, donc lisible
        // pour toujours — même modèle renommé ou supprimé depuis.
        if (templateName != null) ...[
          Text('Modèle · $templateName', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
        ],
        Row(
          children: [
            AppBadge(
              label: session.status.label,
              variant: session.status == WorkoutStatus.completed
                  ? AppBadgeVariant.primary
                  : AppBadgeVariant.neutral,
            ),
            const SizedBox(width: AppSpacing.xs),
            if (session.syncState != LocalSyncState.synced)
              AppBadge(
                label: session.syncState.label,
                variant: session.syncState == LocalSyncState.failed
                    ? AppBadgeVariant.warning
                    : AppBadgeVariant.neutral,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _Metric(label: 'Séries', value: '${workout.setsCount}'),
            _Metric(
              label: 'Volume',
              value: '${workout.totalVolumeKg.round()} kg',
            ),
            _Metric(
              label: 'Durée',
              value: session.durationSeconds == null
                  ? '—'
                  : '${session.durationSeconds! ~/ 60} min',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Séries', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final set in workout.sets)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          set.exerciseName,
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (_plannedLabel(set) != null)
                          Text(
                            _plannedLabel(set)!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if (set.kind != SetKind.normal) ...[
                    AppBadge(label: set.kind.label),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    [
                      if (set.reps != null) '${set.reps}',
                      if (set.weightKg != null) '${set.weightKg} kg',
                    ].join(' × '),
                    style: AppTypography.metric.copyWith(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// « Prévu 8 × 60 kg » — la cible AFFICHÉE au moment de la validation.
///
/// Elle est stockée sur la série elle-même : l'écart prévu/réalisé reste
/// consultable des mois plus tard, indépendamment du modèle d'origine.
String? _plannedLabel(WorkoutSetEntry set) {
  final reps = set.plannedReps;
  final weight = set.plannedWeightKg;
  if (reps == null && weight == null) {
    return null;
  }
  final parts = [
    if (reps != null) formatThousands(reps),
    if (weight != null) '${formatDecimal(weight)} kg',
  ];
  return 'Prévu ${parts.join(' × ')}';
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.metric.copyWith(
              fontSize: 24,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
