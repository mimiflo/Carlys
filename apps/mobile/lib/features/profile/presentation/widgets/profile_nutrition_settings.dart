import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Groupe « NUTRITION ».
///
/// Un seul réglage aujourd'hui, et c'est voulu : le plan nutrition décide de
/// la cible calorique et des macros de la personne. Le loger derrière
/// « Entraînement » revenait à le cacher.
class ProfileNutritionSettings extends StatelessWidget {
  const ProfileNutritionSettings({
    required this.goalLabel,
    required this.onGoal,
    super.key,
  });

  /// Libellé du plan nutrition courant, `null` s'il n'est pas défini.
  final String? goalLabel;
  final VoidCallback onGoal;

  @override
  Widget build(BuildContext context) {
    return AppSettingsGroup(
      label: 'Nutrition',
      rows: [
        AppSettingsRow(
          icon: AppIcons.goal,
          label: 'Mon plan nutrition',
          value: goalLabel,
          onTap: onGoal,
        ),
      ],
    );
  }
}
