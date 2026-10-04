import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/training_profile.dart';
import 'training_setup_sections.dart';

/// La feuille « Ton expérience » : les trois niveaux, un choix, et la
/// feuille se ferme sur la réponse — l'écran l'écrit au serveur, et dit un
/// échec par une notice. Contrairement à la feuille d'objectif, qui écrit
/// elle-même : la même `ExperienceChoices` sert la page du coach, qui écrit
/// sans feuille.
Future<TrainingExperience?> showExperienceSheet(
  BuildContext context, {
  required TrainingExperience? current,
}) {
  return showAppSheet<TrainingExperience>(
    context,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ton expérience',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          ExperienceChoices(
            current: current,
            onChoose: (experience) =>
                Navigator.of(sheetContext).pop(experience),
          ),
        ],
      ),
    ),
  );
}
