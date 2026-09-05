import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_template/presentation/controllers/session_guidance.dart';
import '../../../workout_template/presentation/controllers/workout_template_controllers.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_controllers.dart';
import 'active_workout_bottom_bar.dart';
import 'active_workout_header.dart';
import 'exercise_pane.dart';
import 'exercise_picker_sheet.dart';
import 'workout_close_dialog.dart';
import 'workout_progress_segments.dart';

/// Corps de la séance active : en-tête, progression, exercice en cours,
/// carte de saisie, séries de l'exercice et barre basse (repos ou clôture).
///
/// **Unique point de contact** entre la séance et les modèles : ce corps lit
/// le plan (`sessionPlanProvider`) et le traduit en consigne d'écran
/// ([guidanceFor]). Ni le domaine, ni les données, ni les widgets de la séance
/// ne connaissent les modèles ; sans plan, tout se comporte exactement comme
/// avant — une séance libre reste une séance libre.
class ActiveWorkoutBody extends ConsumerStatefulWidget {
  const ActiveWorkoutBody({required this.workout, super.key});

  final WorkoutWithSets workout;

  /// Repos appliqué quand ni le programme ni une série précédente n'en fixe un.
  static const int _defaultRestSeconds = 90;

  @override
  ConsumerState<ActiveWorkoutBody> createState() => _ActiveWorkoutBodyState();
}

class _ActiveWorkoutBodyState extends ConsumerState<ActiveWorkoutBody> {
  /// Exercice choisi à la main : prioritaire sur le programme comme sur la
  /// dernière série. Faire les exercices dans un autre ordre est autorisé.
  PickedExercise? _picked;

  String get _sessionId => widget.workout.session.id;

  @override
  Widget build(BuildContext context) {
    final sets = widget.workout.sets;
    final plan = ref.watch(sessionPlanProvider(_sessionId)).valueOrNull;
    final guidance = plan == null
        ? null
        : guidanceFor(
            plan,
            pickedExerciseName: _picked?.name,
            pickedExerciseId: _picked?.exerciseId,
          );

    final exercise = _currentExercise(sets, guidance);
    final exerciseSets = exercise == null
        ? const <WorkoutSetEntry>[]
        : sets.where((set) => set.exerciseName == exercise.name).toList();

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        ActiveWorkoutHeader(
          startedAt: widget.workout.session.startedAt,
          sessionName: widget.workout.session.name,
          templateName: widget.workout.session.templateName,
          onClose: () => _close(abandon: true, guidance: guidance),
          onPickExercise: _pickExercise,
        ),
        const SizedBox(height: AppSpacing.gapRow),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: WorkoutProgressSegments(
            completed: sets.length,
            planned: guidance?.upcomingInSession ?? 0,
          ),
        ),
        Expanded(
          child: exercise == null
              ? AppEmptyState(
                  title: 'Aucun exercice',
                  message:
                      'Choisis un exercice pour saisir '
                      'ta première série.',
                  icon: AppIcons.workout,
                  actionLabel: 'Choisir un exercice',
                  onAction: _pickExercise,
                )
              : ExercisePane(
                  exercise: exercise,
                  sessionSetsCount: sets.length,
                  exerciseSets: exerciseSets,
                  previous: _previous(exerciseSets, exercise),
                  overline: guidance?.overline,
                  planItemId: guidance?.planItemId,
                  plannedReps: guidance?.targetReps,
                  plannedWeightKg: guidance?.targetWeightKg,
                  upcomingSets: guidance?.upcomingInExercise ?? 0,
                  onSkipSet: guidance?.planItemId == null
                      ? null
                      : () => ref
                            .read(workoutTemplateActionsProvider)
                            .skipSet(guidance!.planItemId!),
                  onSkipExercise: guidance?.exercisePosition == null
                      ? null
                      : () => ref
                            .read(workoutTemplateActionsProvider)
                            .skipExercise(
                              sessionId: _sessionId,
                              exercisePosition: guidance!.exercisePosition!,
                            ),
                  onValidate: (weightKg, reps) => _validate(
                    exercise,
                    exerciseSets,
                    guidance,
                    weightKg,
                    reps,
                  ),
                  onDelete: (setId) =>
                      ref.read(workoutActionsProvider).deleteSet(setId),
                ),
        ),
        ActiveWorkoutBottomBar(
          onFinish: () => _close(abandon: false, guidance: guidance),
        ),
      ],
    );
  }

  /// Exercice en cours : celui explicitement choisi, sinon celui que le
  /// programme propose, sinon celui de la dernière série enregistrée.
  PickedExercise? _currentExercise(
    List<WorkoutSetEntry> sets,
    SessionGuidance? guidance,
  ) {
    if (_picked != null) {
      return _picked;
    }
    final planned = guidance?.exerciseName;
    if (planned != null) {
      return PickedExercise(name: planned, exerciseId: guidance?.exerciseId);
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

  /// Valide la série **réellement faite**. Le cas d'usage d'appariement
  /// enregistre la série avec ses valeurs réelles, y recopie la cible affichée
  /// et honore l'item de plan correspondant — ou aucun, pour une série
  /// supplémentaire. Une séance libre traverse ce chemin sans rien changer.
  Future<void> _validate(
    PickedExercise exercise,
    List<WorkoutSetEntry> exerciseSets,
    SessionGuidance? guidance,
    double weightKg,
    int reps,
  ) async {
    final restSeconds = guidance?.restSeconds ?? _lastRestSeconds(exerciseSets);

    await ref
        .read(workoutTemplateActionsProvider)
        .recordSet(
          AddSetInput(
            sessionId: _sessionId,
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.name,
            reps: reps,
            weightKg: weightKg,
            restSeconds: restSeconds,
          ),
        );
    ref.read(restTimerProvider.notifier).start(Duration(seconds: restSeconds));
  }

  /// Repos de la série précédente du même exercice, à défaut le repos type.
  int _lastRestSeconds(List<WorkoutSetEntry> exerciseSets) {
    for (final set in exerciseSets.reversed) {
      if (set.restSeconds != null) {
        return set.restSeconds!;
      }
    }
    return ActiveWorkoutBody._defaultRestSeconds;
  }

  Future<void> _close({
    required bool abandon,
    required SessionGuidance? guidance,
  }) async {
    final confirmed = await showWorkoutCloseDialog(
      context,
      abandon: abandon,
      planSummary: guidance?.summary,
    );
    if (confirmed != true || !mounted) {
      return;
    }

    ref.read(restTimerProvider.notifier).stop();
    final actions = ref.read(workoutActionsProvider);
    final templates = ref.read(workoutTemplateActionsProvider);
    final sessionId = _sessionId;

    if (abandon) {
      await actions.abandon(sessionId);
    } else {
      await actions.complete(sessionId);
    }
    // Le plan n'a jamais quitté l'appareil (D5) et plus rien ne le lit une
    // fois la séance close : les cibles atteintes vivent désormais sur les
    // séries elles-mêmes.
    await templates.purgePlan(sessionId);

    if (!mounted) {
      return;
    }
    if (abandon) {
      context.go(AppRoutes.home);
    } else {
      context.pushReplacement(AppRoutes.workoutDetail(sessionId));
    }
  }
}
