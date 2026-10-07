import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';

/// « Muscles sollicités » (maquette d'octobre 2026) : chaque muscle et son
/// RÔLE, la seule donnée que l'API fournit. Le principal porte l'accent, les
/// secondaires le violet — aucune jauge, qui aurait laissé croire à un
/// pourcentage d'activation mesuré.
class ExerciseMusclesCard extends StatelessWidget {
  const ExerciseMusclesCard({required this.muscles, super.key});

  final List<ExerciseMuscleLink> muscles;

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) {
      return const SizedBox.shrink();
    }
    // Le principal d'abord, quel que soit l'ordre servi.
    final ordered = [
      ...muscles.where((link) => link.isPrimary),
      ...muscles.where((link) => !link.isPrimary),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Muscles sollicités',
              style: AppTypography.subheading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (index, link) in ordered.indexed) ...[
            if (index > 0)
              const Divider(height: 1, color: AppColors.rowDivider),
            _MuscleRow(link: link),
          ],
        ],
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({required this.link});

  final ExerciseMuscleLink link;

  @override
  Widget build(BuildContext context) {
    final role = link.isPrimary ? 'Principal' : 'Secondaire';
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                link.muscleGroup.name,
                style: AppTypography.body.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppPill(
              label: role,
              tone: link.isPrimary ? AppPillTone.accent : AppPillTone.primary,
            ),
          ],
        ),
      ),
    );
  }
}
