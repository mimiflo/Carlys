import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_session/presentation/widgets/set_input_sheet.dart';
import '../../domain/entities/exercise.dart';
import 'exercise_records_sheet.dart';

/// Barre d'action basse de la fiche (maquette 2e) : verre dépoli, bouton
/// carré vers l'historique du mouvement, puis le CTA accent unique.
class ExerciseActionBar extends ConsumerWidget {
  const ExerciseActionBar({required this.exercise, super.key});

  final ExerciseDetail exercise;

  static const double _buttonSize = 54;
  static const double _blur = 20;
  static const double _backgroundAlpha = 0.9;
  static const double _historyIconSize = 21;
  static const double _addIconSize = 19;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.darkBackground.withValues(alpha: _backgroundAlpha),
            border: const Border(top: BorderSide(color: AppColors.darkBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.gapRow,
                AppSpacing.gutter,
                AppSpacing.gapRow,
              ),
              child: Row(
                children: [
                  _HistoryButton(exercise: exercise),
                  const SizedBox(width: AppSpacing.gapTile),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(_buttonSize),
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.darkBackground,
                        textStyle: AppTypography.subheading.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => _addToWorkout(context, ref),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AppIcons.add, size: _addIconSize),
                          SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              'Ajouter à la séance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Ajoute une série de cet exercice à la séance en cours — la démarre
  /// au besoin — puis ouvre la séance.
  Future<void> _addToWorkout(BuildContext context, WidgetRef ref) async {
    final input = await showSetInputSheet(context, exerciseName: exercise.name);
    if (input == null || !context.mounted) {
      return;
    }
    final actions = ref.read(workoutActionsProvider);
    final active = ref.read(activeWorkoutProvider).valueOrNull;
    final sessionId = active?.session.id ?? await actions.start();
    await actions.addSet(
      AddSetInput(
        sessionId: sessionId,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        kind: input.kind,
        reps: input.reps,
        weightKg: input.weightKg,
        restSeconds: input.restSeconds,
      ),
    );
    if (context.mounted) {
      await context.push(AppRoutes.activeWorkout);
    }
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.exercise});

  final ExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Historique de ${exercise.name}',
      child: Material(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.buttonAll,
        child: InkWell(
          borderRadius: AppRadius.buttonAll,
          onTap: () => showExerciseRecordsSheet(
            context,
            exerciseId: exercise.id,
            exerciseName: exercise.name,
          ),
          child: Container(
            width: ExerciseActionBar._buttonSize,
            height: ExerciseActionBar._buttonSize,
            decoration: BoxDecoration(
              borderRadius: AppRadius.buttonAll,
              border: Border.all(color: AppColors.darkBorderStrong),
            ),
            child: const Icon(
              AppIcons.history,
              size: ExerciseActionBar._historyIconSize,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
