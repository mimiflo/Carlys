import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../onboarding/presentation/widgets/onboarding_choices.dart';
import '../../domain/entities/training_goal.dart';
import '../providers/training_goal_providers.dart';

/// Feuille « Ton objectif d'entraînement » : huit objectifs, un choix,
/// modifiable à tout moment. La sélection affichée vient de
/// `AuthUser.trainingGoal`, ou du choix montré d'avance le temps de son
/// écriture : choisir ferme la feuille aussitôt, le serveur confirme
/// derrière, et un échec s'affiche en remettant l'objectif d'avant. Même
/// grammaire de cartes que la voix du Mentor : image, nom, ce que
/// l'objectif vise, sélection marquée.
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
                  TrainingGoalChoices(
                    current: current,
                    onChoose: (goal) => _choisir(context, ref, goal),
                  ),
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
    // Même garde que la feuille de voix : la route de LA feuille, pas le
    // navigateur racine (toujours « monté ») — sinon un second toucher
    // pendant la fermeture fermait l'écran du dessous.
    final route = ModalRoute.of(context);
    if (!(route?.isCurrent ?? false)) return;
    final notices = AppNotices.of(context);
    // Le choix se voit aussitôt (montré d'avance) : la feuille se ferme
    // sans attendre le serveur, qui confirme — ou l'écran se remet.
    Navigator.of(context).pop();
    try {
      await ref.read(trainingGoalActionsProvider).choose(goal);
      notices.show(
        'Objectif retenu : ${goal.label}.',
        tone: AppNoticeTone.success,
      );
    } on AppException catch (exception) {
      notices.show(exception.message, tone: AppNoticeTone.error);
    }
  }
}

/// Les huit objectifs en cartes de choix, l'actuel marqué : la feuille et
/// la page « Avant que je réfléchisse » du coach les montrent à l'identique.
class TrainingGoalChoices extends StatelessWidget {
  const TrainingGoalChoices({
    required this.current,
    required this.onChoose,
    super.key,
  });

  final TrainingGoal? current;
  final ValueChanged<TrainingGoal> onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final goal in TrainingGoal.values) ...[
          // La carte de choix du design system : on n'apporte que le
          // contenu de l'objectif.
          AppChoiceCard(
            icon: trainingGoalIcon(goal),
            title: goal.label,
            description: goal.description,
            selected: goal == current,
            selectedSemantics: 'Objectif actuel.',
            onTap: () => onChoose(goal),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}
