import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../domain/entities/nutrition.dart';
import 'dna_helix.dart';

/// Hero « métabolisme » (2b) : hélice ADN décalée à droite, gradient
/// latéral pour la colonne de texte, dépense totale en très grand.
class MetabolismHero extends StatelessWidget {
  const MetabolismHero({required this.metabolism, super.key});

  final MetabolismResult? metabolism;

  static String formatKcal(int value) {
    final text = '$value';
    if (text.length <= 3) return text;
    return '${text.substring(0, text.length - 3)} ${text.substring(text.length - 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final tdee = metabolism?.tdeeKcal;
    final bmr = metabolism?.bmrKcal;
    final activity = tdee == null || bmr == null ? null : tdee - bmr;

    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          // Hélice décalée à droite, jamais sous le texte sans scrim.
          const Positioned(
            top: 0,
            right: -60,
            child: AppSceneContainer(
              size: 300,
              opacity: 0.85,
              verticalFadeStops: [0.0, 0.16, 0.62, 0.94],
              child: Center(child: DnaHelix(height: 260)),
            ),
          ),
          const Positioned.fill(child: AppSceneScrim.lateral()),
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionLabel('Métabolisme'),
                const SizedBox(height: 10),
                Text(
                  'Ton moteur\naujourd’hui',
                  style: AppTypography.display
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tdee == null ? '—' : formatKcal(tdee),
                            style: AppTypography.metricXL
                                .copyWith(color: AppColors.accent),
                          ),
                          const SizedBox(height: 8),
                          const AppSectionLabel(
                            'Kcal / dépense totale',
                            color: AppColors.darkTextTertiary,
                          ),
                        ],
                      ),
                    ),
                    if (bmr != null && activity != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AppSectionLabel(
                            'MB ${formatKcal(bmr)}',
                            color: AppColors.darkTextTertiary,
                          ),
                          const SizedBox(height: 6),
                          AppSectionLabel(
                            'Activité ${formatKcal(activity)}',
                            color: AppColors.darkTextTertiary,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
