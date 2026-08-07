import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_controllers.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/rest_timer_bar.dart';
import '../widgets/set_input_sheet.dart';

/// Séance active : saisie des séries, minuteur de repos, clôture.
/// Toutes les écritures partent dans la base locale — utilisable hors ligne.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Séance en cours')),
      body: SafeArea(
        child: workout.when(
          loading: () => const AppLoadingIndicator(label: 'Chargement'),
          error: (_, __) => const AppErrorState(
            title: 'Séance indisponible',
          ),
          data: (active) => active == null
              ? const AppEmptyState(
                  title: 'Aucune séance en cours',
                  message: 'Démarrez une séance depuis l’accueil.',
                  icon: AppIcons.timer,
                )
              : _ActiveWorkoutBody(workout: active),
        ),
      ),
    );
  }
}

class _ActiveWorkoutBody extends ConsumerWidget {
  const _ActiveWorkoutBody({required this.workout});

  final WorkoutWithSets workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _ElapsedHeader(startedAt: workout.session.startedAt),
        const RestTimerBar(),
        Expanded(
          child: workout.sets.isEmpty
              ? const AppEmptyState(
                  title: 'Première série ?',
                  message: 'Ajoutez un exercice pour commencer votre séance.',
                  icon: AppIcons.workout,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: workout.sets.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) =>
                      _SetTile(set: workout.sets[index]),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: 'Ajouter une série',
                  icon: AppIcons.add,
                  isExpanded: true,
                  onPressed: () => _addSet(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Abandonner',
                        variant: AppButtonVariant.ghost,
                        onPressed: () => _close(context, ref, abandon: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Terminer',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => _close(context, ref, abandon: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${workout.setsCount} série(s) — '
                  '${workout.totalVolumeKg.round()} kg de volume',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addSet(BuildContext context, WidgetRef ref) async {
    final picked = await showExercisePickerSheet(context);
    if (picked == null || !context.mounted) {
      return;
    }
    final input = await showSetInputSheet(context, exerciseName: picked.name);
    if (input == null) {
      return;
    }
    await ref.read(workoutActionsProvider).addSet(
          AddSetInput(
            sessionId: workout.session.id,
            exerciseId: picked.exerciseId,
            exerciseName: picked.name,
            kind: input.kind,
            reps: input.reps,
            weightKg: input.weightKg,
            restSeconds: input.restSeconds,
          ),
        );
    ref
        .read(restTimerProvider.notifier)
        .start(Duration(seconds: input.restSeconds));
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref, {
    required bool abandon,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(abandon ? 'Abandonner la séance ?' : 'Terminer la séance ?'),
        content: Text(
          abandon
              ? 'La séance sera marquée comme abandonnée.'
              : 'Vos séries sont enregistrées et seront synchronisées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    ref.read(restTimerProvider.notifier).stop();
    final actions = ref.read(workoutActionsProvider);
    if (abandon) {
      await actions.abandon(workout.session.id);
      if (context.mounted) {
        context.go(AppRoutes.home);
      }
    } else {
      await actions.complete(workout.session.id);
      if (context.mounted) {
        context.pushReplacement(AppRoutes.workoutDetail(workout.session.id));
      }
    }
  }
}

class _ElapsedHeader extends StatelessWidget {
  const _ElapsedHeader({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      builder: (context, snapshot) {
        final elapsed =
            (snapshot.data ?? DateTime.now()).difference(startedAt.toLocal());
        final hours = elapsed.inHours;
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds',
            textAlign: TextAlign.center,
            style: AppTypography.metric.copyWith(
              color: theme.colorScheme.primary,
            ),
            semanticsLabel: 'Durée écoulée',
          ),
        );
      },
    );
  }
}

class _SetTile extends ConsumerWidget {
  const _SetTile({required this.set});

  final WorkoutSetEntry set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detail = [
      if (set.reps != null) '${set.reps} reps',
      if (set.weightKg != null) '${_formatWeight(set.weightKg!)} kg',
    ].join(' × ');

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(set.exerciseName, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    if (set.kind != SetKind.normal) ...[
                      AppBadge(label: set.kind.label),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          if (set.syncState == LocalSyncState.pending)
            Tooltip(
              message: 'En attente de synchronisation',
              child: Icon(
                AppIcons.offline,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          IconButton(
            tooltip: 'Supprimer la série',
            icon: Icon(AppIcons.delete, color: theme.colorScheme.error),
            onPressed: () =>
                ref.read(workoutActionsProvider).deleteSet(set.id),
          ),
        ],
      ),
    );
  }
}

String _formatWeight(double weight) => weight == weight.roundToDouble()
    ? weight.toStringAsFixed(0)
    : weight.toStringAsFixed(1);
