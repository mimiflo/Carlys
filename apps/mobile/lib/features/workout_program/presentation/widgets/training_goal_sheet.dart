import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../onboarding/presentation/widgets/onboarding_choices.dart';
import '../../domain/entities/training_goal.dart';
import '../controllers/training_goal_controllers.dart';

/// Feuille « Ton objectif d'entraînement » : huit objectifs, un choix,
/// modifiable à tout moment. La sélection affichée vient de
/// `AuthUser.trainingGoal` (une seule source de vérité) ; choisir écrit au
/// serveur puis rafraîchit l'utilisateur, et un échec s'affiche sans rien
/// changer. Même grammaire de cartes que la voix du Mentor : image, nom,
/// ce que l'objectif vise, sélection marquée.
Future<void> showTrainingGoalSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (_) => const _TrainingGoalSheet(),
  );
}

class _TrainingGoalSheet extends ConsumerWidget {
  const _TrainingGoalSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrainingGoalProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ton objectif d’entraînement',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Le pourquoi de tes séances, distinct de ton plan nutrition. '
            'Ton futur programme partira de là.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final goal in TrainingGoal.values) ...[
                    _GoalRow(
                      goal: goal,
                      current: goal == current,
                      onChoose: () => _choisir(context, ref, goal),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _choisir(
    BuildContext context,
    WidgetRef ref,
    TrainingGoal goal,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(trainingGoalActionsProvider).choose(goal);
      if (navigator.mounted) {
        navigator.pop();
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Objectif retenu : ${goal.label}.')),
      );
    } on AppException catch (exception) {
      messenger.showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }
}

/// Un objectif : son image, son nom, ce qu'il vise, l'état « choisi ».
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.current,
    required this.onChoose,
  });

  final TrainingGoal goal;
  final bool current;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: current,
      label:
          '${goal.label}. ${goal.description}'
          '${current ? ' Objectif actuel.' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onChoose,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: current
                ? AppColors.primaryCardSoft
                : AppColors.darkSurfaceAlt,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(
                color: current ? AppColors.primaryLight : AppColors.darkBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBadgeBg,
                ),
                child: Icon(
                  trainingGoalIcon(goal),
                  size: 18,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      goal.description,
                      style: AppTypography.label.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (current) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  AppIcons.checkCircle,
                  size: 18,
                  color: AppColors.primaryLight,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
