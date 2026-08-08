import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';

/// Indice de forme : très grand nombre mono accent, légende mono et lecture
/// courte adaptée au score.
///
/// Le score est le taux d'accomplissement de l'objectif hebdomadaire de
/// séances (voir `fitnessIndexProvider`) — aucune donnée de santé n'existe
/// côté domaine.
class FitnessIndexBlock extends StatelessWidget {
  const FitnessIndexBlock({required this.score, super.key});

  /// 0..100, `null` tant que la semaine n'est pas connue.
  final int? score;

  /// Géométrie de la maquette : chiffre mono 62, interligne serré.
  static const double _numberSize = 62;
  static const double _numberHeight = 0.85;
  static const double _numberTracking = -3.1;

  /// Ajustement optique : la légende s'assoit sur la base du chiffre.
  static const double _legendBaseline = 5;

  @override
  Widget build(BuildContext context) {
    final value = score;
    final reading = switch (value) {
      null => null,
      0 => 'La semaine commence',
      >= 100 => 'Objectif atteint',
      _ => 'Prêt pour du lourd',
    };

    return Semantics(
      label: value == null
          ? 'Indice de forme indisponible'
          : 'Indice de forme : $value sur 100. $reading',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value == null ? '—' : formatThousands(value),
              style: AppTypography.metricXL.copyWith(
                fontSize: _numberSize,
                height: _numberHeight,
                letterSpacing: _numberTracking,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: _legendBaseline),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppSectionLabel('Indice de forme'),
                    if (reading != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        reading,
                        style: AppTypography.body.copyWith(
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
