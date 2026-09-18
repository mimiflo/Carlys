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
                    // La carte de choix du design system : la feuille
                    // n'apporte que le contenu de l'objectif.
                    AppChoiceCard(
                      icon: trainingGoalIcon(goal),
                      title: goal.label,
                      description: goal.description,
                      selected: goal == current,
                      selectedSemantics: 'Objectif actuel.',
                      onTap: () => _choisir(context, ref, goal),
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
