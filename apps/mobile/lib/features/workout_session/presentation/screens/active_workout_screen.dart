import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_controllers.dart';
import '../widgets/active_set_row.dart';
import '../widgets/active_workout_header.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/rest_timer_bar.dart';
import '../widgets/set_input_sheet.dart';

/// Séance active (maquette 2c) : mode plein écran sans bottom bar, saisie
/// des séries, minuteur de repos, clôture. Écritures 100 % locales.
class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // Cœur ambiant recadré en tête — jamais sous les cartes.
          const Positioned(
            top: -104,
            left: 0,
            right: 0,
            child: Center(
              child: AppSceneContainer(
                size: 360,
                opacity: 0.32,
                verticalFadeStops: [0.0, 0.02, 0.40, 0.82],
                child: HeartScene(),
              ),
            ),
          ),
          SafeArea(
            child: workout.when(
              loading: () => const AppLoadingIndicator(label: 'Chargement'),
              error: (_, __) =>
                  const AppErrorState(title: 'Séance indisponible'),
              data: (active) => active == null
                  ? const AppEmptyState(
                      title: 'Aucune séance en cours',
                      message: 'Démarrez une séance depuis l’accueil.',
                      icon: AppIcons.timer,
                    )
                  : _ActiveWorkoutBody(workout: active),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutBody extends ConsumerWidget {
  const _ActiveWorkoutBody({required this.workout});

  final WorkoutWithSets workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ActiveWorkoutHeader(
          startedAt: workout.session.startedAt,
          onClose: () => _close(context, ref, abandon: true),
          onFinish: () => _close(context, ref, abandon: false),
        ),
        const RestTimerBar(),
        Expanded(
          child: workout.sets.isEmpty
              ? const AppEmptyState(
                  title: 'Première série ?',
                  message: 'Ajoutez un exercice pour commencer votre séance.',
                  icon: AppIcons.workout,
                )
              // Fondu de conteneur : le rognage se lit comme un défilement.
              : ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.86, 0.99],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      AppSpacing.xl,
                    ),
                    itemCount: workout.sets.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) => ActiveSetRow(
                      set: workout.sets[index],
                      // La dernière série saisie est la série « active ».
                      highlighted: index == workout.sets.length - 1,
                    ),
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // L'unique CTA accent de l'écran.
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.darkBackground,
                  ),
                  onPressed: () => _addSet(context, ref),
                  child: const Text('Série suivante'),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: AppSectionLabel(
                    '${workout.setsCount} séries · '
                    '${workout.totalVolumeKg.round()} kg',
                    color: AppColors.darkTextTertiary,
                  ),
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
        title:
            Text(abandon ? 'Abandonner la séance ?' : 'Terminer la séance ?'),
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
