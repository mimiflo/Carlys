import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Ce qui rend une photo LISIBLE pour l'IA : c'est d'elle que dépend la
/// justesse du scan, plus que de tout réglage du modèle (ADR 0015).
class MealScanTips extends StatelessWidget {
  const MealScanTips({super.key});

  static const _tips = [
    (
      AppIcons.scanTipFromAbove,
      'Vue de dessus, l’assiette entière',
      'Rien de coupé au bord',
    ),
    (
      AppIcons.scanTipLight,
      'En pleine lumière',
      'Près d’une fenêtre, sans ombre',
    ),
    (
      AppIcons.scanTipVisible,
      'Chaque aliment visible',
      'Une assiette par photo',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'Pour une détection juste'),
        const SizedBox(height: AppSpacing.xs),
        for (final (icon, title, detail) in _tips) ...[
          AppListRow(leading: icon, title: title, subtitle: detail),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}
