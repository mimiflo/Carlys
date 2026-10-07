import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/training_profile.dart';

/// Les choix de rythme proposés — les bornes du contrat sont plus larges
/// (1 à 7, 15 à 240) : ces listes sont des PROPOSITIONS, pas des limites.
const List<int> weeklySessionsChoices = [2, 3, 4, 5, 6];
const List<int> sessionMinutesChoices = [30, 45, 60, 75, 90];

/// L'expérience : trois cartes de choix du design system, une sélection.
class ExperienceChoices extends StatelessWidget {
  const ExperienceChoices({
    required this.current,
    required this.onChoose,
    super.key,
  });

  final TrainingExperience? current;
  final ValueChanged<TrainingExperience> onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final experience in TrainingExperience.values) ...[
          AppChoiceCard(
            title: experience.label,
            description: experience.description,
            selected: experience == current,
            selectedSemantics: 'Expérience actuelle.',
            onTap: () => onChoose(experience),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}
