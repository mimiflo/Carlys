import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_controllers.dart';
import 'active_workout_bottom_bar.dart';
import 'active_workout_header.dart';
import 'exercise_pane.dart';
import 'exercise_picker_sheet.dart';
import 'workout_progress_segments.dart';

/// Corps de la séance active : en-tête, progression, exercice en cours,
/// carte de saisie, séries de l'exercice et barre basse (repos ou clôture).
class ActiveWorkoutBody extends ConsumerStatefulWidget {
  const ActiveWorkoutBody({required this.workout, super.key});

  final WorkoutWithSets workout;

  /// Repos appliqué quand aucune série précédente n'en fixe un.
  static const int _defaultRestSeconds = 90;

  @override
  ConsumerState<ActiveWorkoutBody> createState() => _ActiveWorkoutBodyState();
}

class _ActiveWorkoutBodyState extends ConsumerState<ActiveWorkoutBody> {
  /// Exercice choisi à la main : prioritaire sur celui de la dernière série.
  PickedExercise? _picked;

  @override
  Widget build(BuildContext context) {
    final sets = widget.workout.sets;
    final exercise = _currentExercise(sets);
    final exerciseSets = exercise == null
        ? const <WorkoutSetEntry>[]
        : sets.where((set) => set.exerciseName == exercise.name).toList();
    final previous = _previous(exerciseSets, exercise);

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        ActiveWorkoutHeader(
          startedAt: widget.workout.session.startedAt,
          sessionName: widget.workout.session.name,
          onClose: () => _close(abandon: true),
          onPickExercise: _pickExercise,
        ),
        const SizedBox(height: AppSpacing.gapRow),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: WorkoutProgressSegments(completed: sets.length),
        ),
        Expanded(
          child: exercise == null
              ? AppEmptyState(
                  title: 'Aucun exercice',
                  message: 'Choisissez un exercice pour saisir '
                      'votre première série.',
                  icon: AppIcons.workout,
                  actionLabel: 'Choisir un exercice',
                  onAction: _pickExercise,
                )
              : ExercisePane(
                  exercise: exercise,
                  sessionSetsCount: sets.length,
                  exerciseSets: exerciseSets,
                  previous: previous,
                  onValidate: (weightKg, reps) =>
                      _validate(exercise, exerciseSets, weightKg, reps),
                  onDelete: (setId) =>
                      ref.read(workoutActionsProvider).deleteSet(setId),
                ),
        ),
        ActiveWorkoutBottomBar(onFinish: () => _close(abandon: false)),
      ],
    );
  }

  /// Exercice en cours : celui explicitement choisi, sinon celui de la
  /// dernière série enregistrée.
  PickedExercise? _currentExercise(List<WorkoutSetEntry> sets) {
    if (_picked != null) {
      return _picked;
    }
    if (sets.isEmpty) {
      return null;
    }
    final last = sets.last;
    return PickedExercise(name: last.exerciseName, exerciseId: last.exerciseId);
  }

  /// Dernière performance connue : d'abord dans la séance en cours, sinon
  /// dans les séances passées.
  WorkoutSetEntry? _previous(
    List<WorkoutSetEntry> exerciseSets,
    PickedExercise? exercise,
  ) {
    for (final set in exerciseSets.reversed) {
      if (set.reps != null && set.weightKg != null) {
        return set;
      }
    }
    if (exercise == null) {
      return null;
    }
    return ref.watch(previousPerformanceProvider(exercise.name)).valueOrNull;
  }

  Future<void> _pickExercise() async {
    final picked = await showExercisePickerSheet(context);
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _picked = picked);
  }

  Future<void> _validate(
    PickedExercise exercise,
    List<WorkoutSetEntry> exerciseSets,
    double weightKg,
    int reps,
  ) async {
    // Repos de la série précédente du même exercice, à défaut le repos type.
    var restSeconds = ActiveWorkoutBody._defaultRestSeconds;
    for (final set in exerciseSets.reversed) {
      if (set.restSeconds != null) {
        restSeconds = set.restSeconds!;
        break;
      }
    }

    await ref.read(workoutActionsProvider).addSet(
          AddSetInput(
            sessionId: widget.workout.session.id,
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.name,
            reps: reps,
            weightKg: weightKg,
            restSeconds: restSeconds,
          ),
        );
    ref.read(restTimerProvider.notifier).start(Duration(seconds: restSeconds));
  }

  Future<void> _close({required bool abandon}) async {
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
    if (confirmed != true || !mounted) {
      return;
    }

    ref.read(restTimerProvider.notifier).stop();
    final actions = ref.read(workoutActionsProvider);
    final sessionId = widget.workout.session.id;
    if (abandon) {
      await actions.abandon(sessionId);
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } else {
      await actions.complete(sessionId);
      if (mounted) {
        context.pushReplacement(AppRoutes.workoutDetail(sessionId));
      }
    }
  }
}
