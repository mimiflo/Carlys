import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

/// Indicateur de difficulté de la maquette : trois tirets 16×3, remplis en
/// accent selon le niveau (1 = débutant, 2 = intermédiaire, 3 = avancé).
class AppDifficultyDashes extends StatelessWidget {
  const AppDifficultyDashes({
    required this.level,
    required this.semanticLabel,
    super.key,
  });

  /// Niveau atteint, borné à 1..3.
  final int level;

  /// Libellé lu par les lecteurs d'écran (ex. « Difficulté : Intermédiaire »).
  final String semanticLabel;

  static const double _dashWidth = 16;
  static const double _dashHeight = 3;
  static const int _steps = 3;

  @override
  Widget build(BuildContext context) {
    final filled = level.clamp(1, _steps);
    return Semantics(
      label: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < _steps; index++) ...[
            if (index > 0) const SizedBox(width: 5),
            Container(
              width: _dashWidth,
              height: _dashHeight,
              decoration: BoxDecoration(
                color: index < filled
                    ? AppColors.accent
                    : AppColors.difficultyTrack,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
