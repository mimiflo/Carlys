import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/perceived_effort.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../../workout_session/domain/services/recovery_advice.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../providers/session_muscle_groups.dart';
import '../utils/recovery_sentence.dart';
import 'finished_set_actions.dart';

/// « Comment c'était ? » : l'effort perçu de la séance entière, en cinq
/// réponses posées sur l'échelle de Borg CR10, puis le repos conseillé.
///
/// Facultatif et modifiable : toucher la réponse choisie la retire. Le
/// choix s'écrit en local puis part en file — il tient hors ligne, après la
/// clôture comme des semaines plus tard.
class SessionEffortCard extends ConsumerWidget {
  const SessionEffortCard({required this.workout, super.key});

  final WorkoutWithSets workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = workout.session;
    final selected = EffortChoice.fromBorg(session.perceivedEffort);
    final advice = recoveryAdvice(
      perceivedEffort: session.perceivedEffort,
      endedAt: session.endedAt,
      muscleGroups:
          ref
              .watch(
                sessionMuscleGroupsProvider(
                  sessionExerciseIdsKey(workout.sets),
                ),
              )
              .valueOrNull ??
          const [],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Comment c’était ?',
              style: AppTypography.subheading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Ton effort sur toute la séance. Facultatif, modifiable.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppChoicePills<EffortChoice?>(
            choices: [
              for (final choice in EffortChoice.values)
                AppChoice(choice, choice.label),
            ],
            selected: selected,
            onSelected: (choice) => writeFinishedSession(
              context,
              () => ref
                  .read(workoutActionsProvider)
                  .ratePerceivedEffort(
                    session.id,
                    choice == selected ? null : choice?.borg,
                  ),
            ),
          ),
          if (advice != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _RecoveryAdvice(advice: advice),
          ],
        ],
      ),
    );
  }
}

class _RecoveryAdvice extends StatelessWidget {
  const _RecoveryAdvice({required this.advice});

  final RecoveryAdvice advice;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(AppIcons.restDay, color: AppColors.primaryLight),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  recoverySentence(advice, now: DateTime.now()),
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Repère général d’entraînement (recommandation ACSM : 48 h entre '
            'deux séances d’un même groupe musculaire), pas un avis médical.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
