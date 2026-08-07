import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../progress/domain/entities/progress.dart';

/// Carte de forme (glass) : anneau de score + lecture de la semaine.
/// Le score est le taux d'accomplissement hebdomadaire (5 séances visées).
class FormeCard extends StatelessWidget {
  const FormeCard({required this.week, super.key});

  final ProgressOverviewEntity? week;

  static const int weeklyTarget = 5;

  @override
  Widget build(BuildContext context) {
    final sessions = week?.sessionsCount ?? 0;
    final capped = sessions.clamp(0, weeklyTarget);
    final score = (capped / weeklyTarget * 100).round();
    final (headline, detail) = switch (capped) {
      0 => (
          'La semaine commence.',
          'Aucune séance enregistrée pour l’instant — la première donne le ton.',
        ),
      >= weeklyTarget => (
          'Objectif atteint.',
          'Cinq séances cette semaine : pense à la récupération.',
        ),
      _ => (
          'Prêt pour du lourd.',
          '$capped séance${capped > 1 ? 's' : ''} cette semaine — '
              'encore ${weeklyTarget - capped} pour l’objectif.',
        ),
    };

    return AppGlassCard(
      child: Row(
        children: [
          AppFormRing(value: score, label: 'Indice'),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AppTypography.heading
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: AppTypography.body
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
