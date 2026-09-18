import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Groupe « ENTRAÎNEMENT ».
///
/// Les lignes « temps de repos par défaut » et « unités » de la maquette sont
/// absentes : aucun réglage correspondant n'existe dans le domaine.
///
/// La ligne « Objectif » a QUITTÉ ce groupe en septembre 2026 : elle porte un
/// `NutritionGoal`, donc elle pilote les calories et les macros, pas les
/// charges. Rangée sous « Entraînement » et nommée d'un mot qui recouvre au
/// moins deux notions distinctes, elle laissait croire qu'on y choisissait un
/// but d'entraînement. Elle vit maintenant dans son propre groupe, sous un
/// nom qui dit ce qu'elle fait — et depuis le Plan 4, le VRAI objectif
/// d'entraînement (`TrainingGoal`) a sa ligne ici, en tête de groupe.
class ProfileTrainingSettings extends StatelessWidget {
  const ProfileTrainingSettings({
    required this.goalLabel,
    required this.onGoal,
    required this.onSetup,
    required this.onTemplates,
    required this.onHistory,
    required this.onBodyMetrics,
    super.key,
  });

  /// Libellé de l'objectif d'entraînement choisi, `null` tant qu'aucun ne
  /// l'est.
  final String? goalLabel;

  /// Ouvre la feuille de choix de l'objectif d'entraînement.
  final VoidCallback onGoal;

  /// Ouvre « Préparer mon programme » : les entrées de génération.
  final VoidCallback onSetup;

  /// Ouvre « Mes modèles » : gérer ses séances types est un réglage
  /// d'entraînement, pas un geste de démarrage.
  final VoidCallback onTemplates;
  final VoidCallback onHistory;
  final VoidCallback onBodyMetrics;

  @override
  Widget build(BuildContext context) {
    return AppSettingsGroup(
      label: 'Entraînement',
      rows: [
        AppSettingsRow(
          icon: AppIcons.goal,
          label: 'Mon objectif',
          value: goalLabel ?? 'À choisir',
          onTap: onGoal,
        ),
        AppSettingsRow(
          icon: AppIcons.programs,
          label: 'Préparer mon programme',
          onTap: onSetup,
        ),
        AppSettingsRow(
          icon: AppIcons.programs,
          label: 'Mes modèles de séance',
          onTap: onTemplates,
        ),
        AppSettingsRow(
          icon: AppIcons.history,
          label: 'Historique des séances',
          onTap: onHistory,
        ),
        AppSettingsRow(
          icon: AppIcons.bodyMetrics,
          label: 'Mesures corporelles',
          onTap: onBodyMetrics,
        ),
      ],
    );
  }
}
